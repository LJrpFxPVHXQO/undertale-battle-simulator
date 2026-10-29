import argparse
import glob
import os
from PIL import Image
from bw_utils import img2tiles, arr2tiles, name2const, spritest2chr, get_imgs_from_csv
from rle_inc import rleinc_encode, rleinc_decode
import numpy as np


def find_spr_in_list(t, tile_list) -> tuple[int, tuple[bool, bool]]:
    # try H=False, V=False
    for i, t1 in enumerate(tile_list):
        if np.equal(t, t1).all():
            return i, (False, False)

    # try H=False, V=True
    f = np.flip(t, axis=0)
    for i, t1 in enumerate(tile_list):
        if np.equal(f, t1).all():
            return i, (False, True)

    # try H=True, V=False
    f = np.flip(t, axis=1)
    for i, t1 in enumerate(tile_list):
        if np.equal(f, t1).all():
            return i, (True, False)

    # try H=True, V=True
    f = np.flip(t)
    for i, t1 in enumerate(tile_list):
        if np.equal(f, t1).all():
            return i, (True, True)

    return -1, (False, False)


def tiles_score_in_list(tiles, bnk):
    n_free = sum([1 for x in bnk if np.sum(x) == 0])
    score_free = 0
    score_same = 0
    for t in tiles:
        i, _ = find_spr_in_list(t, bnk)
        if i < 0:
            if score_free < n_free:
                score_free += 1
        else:
            score_same += 1
    return (score_same, score_free)


# consts
PALETTE = 0x20
FLIP_H = 0x40
FLIP_V = 0x80
BNK_SIZE = 64

# args
parser = argparse.ArgumentParser()
parser.add_argument("folder", help="folder containing mosnter images")
parser.add_argument("-c", "--chrfile", default="test.chr")
parser.add_argument("-d", "--datafile", default="test.bin")
parser.add_argument("-cf", "--constfile", default="const.asm")
parser.add_argument("-b", "--bnk", default=0)
parser.add_argument("-bs", "--bnk_size_from", default="")
parser.add_argument("-cc", "--colorchrfile", default="", help="CHR file for sprite_color images")
parser.add_argument("-cb", "--colorbnk", type=int, default=0, help="first 1KB CHR bank of the sprite_color CHR file")
args = parser.parse_args()

args.bnk = int(args.bnk)
if args.bnk_size_from != "":
    size = os.path.getsize(args.bnk_size_from)
    if size % 1024 != 0:
        size += 1024 - (size % 1024)
    args.bnk += size >> 10

# init phase
tile_list = []
data_list = []  # {"name": "", "size": (), "data":[]}

# getting phase
csv_filenames = glob.glob(os.path.join(args.folder, "**/*.csv"), recursive=True)
img_filenames = get_imgs_from_csv(csv_filenames, type="sprite")

# process phase
for imgname in img_filenames:
    # open image
    img = Image.open(imgname).convert("RGB")

    # if number of color exeed 2
    if not img.getcolors(maxcolors=2):
        # skip
        print("Warning: number of color exeed 2 on img", imgname, ". ignoring")
        continue

    # cut image into tiles and data
    size, tiles, data = img2tiles(img, th=16)
    # if sprite have too many tiles
    if len(tiles) > BNK_SIZE // 2:
        # skip
        print("Error: sprite", imgname, "have too many tiles. ignoring")
        continue

    # compute score to know in which bank to add sprites
    n_bnk = len(tile_list) // BNK_SIZE + 1
    best_bnk = 0
    scores = {}
    for i in range(n_bnk):
        bnk = tile_list[i * BNK_SIZE : i * BNK_SIZE + BNK_SIZE]
        scores[i] = tiles_score_in_list(tiles, bnk)
    # find best sprite bank
    scores = sorted(scores.items(), key=lambda x: x[1][0])
    best_score = sum(scores[0][1])
    best_bnk = scores[0][0]
    # if no bank has been found
    if best_score < len(tiles):
        # take the last one
        best_bnk = len(tile_list) // BNK_SIZE
    # add sprite tiles in the correct bnk
    for i, t in enumerate(tiles):
        # find if tile aleardy there
        bnk = tile_list[best_bnk * BNK_SIZE : best_bnk * BNK_SIZE + BNK_SIZE]
        idx, a = find_spr_in_list(t, bnk)
        # if yes
        if idx >= 0:
            data[i] = idx
        else:
            data[i] = len(bnk)
            tile_list.append(t)
        # shift 1 left and change bit 5 to bit 0
        data[i] = ((data[i] & 0x1F) << 1) + ((data[i] & 0x20) >> 5)
        # add vertical and horizontal flip flags
        data[i] += 0x40 if a[0] else 0
        data[i] += 0x80 if a[1] else 0

    # add formated data to the list
    data_list.append(
        {
            "name": imgname,
            "size": size,
            "data": data,
            "bnk": best_bnk,
        }
    )


# color sprites: every non black pixel is color 3 of sprite palette 0.
# Each 8x16 tile uses both bitplanes, so a 1KB bank holds 32 tiles.
COLOR_BNK_TILES = BNK_SIZE // 2
color_banks = []  # list of lists of tiles
color_imgs = get_imgs_from_csv(csv_filenames, type="sprite_color")
for imgname in color_imgs:
    img = Image.open(imgname).convert("RGB")
    arr = (np.array(img).sum(axis=2) > 0).astype(np.int8) * 3
    size, tiles, data = arr2tiles(arr, img.width, img.height, th=16)

    # find a bank where all the new tiles fit
    best_bnk = -1
    for b, bnk in enumerate(color_banks):
        n_new = len({t.tobytes() for t in tiles if not any(np.equal(t, t1).all() for t1 in bnk)})
        if len(bnk) + n_new <= COLOR_BNK_TILES:
            best_bnk = b
            break
    if best_bnk < 0:
        if len(set(t.tobytes() for t in tiles)) > COLOR_BNK_TILES:
            print("Error: sprite", imgname, "have too many tiles. ignoring")
            continue
        color_banks.append([])
        best_bnk = len(color_banks) - 1

    bnk = color_banks[best_bnk]
    for i, t in enumerate(tiles):
        idx = next((j for j, t1 in enumerate(bnk) if np.equal(t, t1).all()), -1)
        if idx < 0:
            idx = len(bnk)
            bnk.append(t)
        # tile index << 1, palette bit = 0
        data[i] = idx << 1

    data_list.append(
        {
            "name": imgname,
            "size": size,
            "data": data,
            "bnk": args.colorbnk + best_bnk - args.bnk,
        }
    )

if args.colorchrfile != "" and color_banks:
    with open(args.colorchrfile, "wb") as f:
        for bnk in color_banks:
            f.write(bytes(spritest2chr(bnk)))
            f.write(bytes(1024 - len(bnk) * 32))


# tile merge phase
for b in range(len(tile_list) // BNK_SIZE + 1):
    bnk = tile_list[b * BNK_SIZE : b * BNK_SIZE + BNK_SIZE]
    l = len(bnk) - BNK_SIZE // 2
    if l > 0:
        for i in range(l):
            tile_list[b * BNK_SIZE + i] = (tile_list[b * BNK_SIZE + i]) + (tile_list[b * BNK_SIZE + (BNK_SIZE // 2) + i] << 1)


# CHR phase
chr = spritest2chr(tile_list)  # convert tiles to CHR
# write CHR to file
with open(args.chrfile, "wb") as f:
    f.write(bytes(chr))
    m = len(chr) % 1024
    if m > 0:
        f.write(bytes(1024 - m))

# compression phase
data_bin = bytearray()
for data in data_list:
    # width and height
    w, h = data["size"]
    # compressed data
    d = rleinc_encode(data["data"])  # , doprint=True)
    # print(rleinc_decode(d, doprint=True))

    data_bin.append(len(d) + 2)
    data_bin.append((w & 0xF) + ((h & 0xF) << 4))
    data_bin.append(data["bnk"] + args.bnk)
    data_bin.extend(d)

# write to file
with open(args.datafile, "wb") as f:
    f.write(data_bin)
    if len(data_bin) % 1024 > 0:
        f.write(bytes(1024 - len(data_bin) % 1024))
with open(args.constfile, "w") as f:
    f.write("""
; sprites image constant
""")
    for i, data in enumerate(data_list):
        name = name2const(data["name"])
        f.write(f"IMG_{name} = _IMG_LAST_BKG + _IMG_LAST_BKG_CL + {i}\n")
