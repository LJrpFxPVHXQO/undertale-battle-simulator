
.segment "MONSTER_ANIM_DATA"

anim_data:
    ; ANIM_DATA_MONSTERS_DUMMY_NORMAL
    .byte 240, 32, 0, 0 ; x, y, delay, type
    .word IMG_DATA_MONSTERS_DUMMY_DUMMY_0, 0 ; img, next
    ; ANIM_DATA_MONSTERS_EMBER_EMBER_BKG
    .byte 224, 24, 0, 0 ; x, y, delay, type
    .word IMG_DATA_MONSTERS_EMBER_EMBER_BOSS, 0 ; img, next
    ; ANIM_DATA_MONSTERS_FROGGIT_FROGGIT_BKG
    .byte 232, 32, 0, 0 ; x, y, delay, type
    .word IMG_DATA_MONSTERS_FROGGIT_FROGGIT, 0 ; img, next
    ; ANIM_DATA_MONSTERS_SANS_SANS_BKG
    .byte 224, 8, 0, 0 ; x, y, delay, type
    .word IMG_DATA_MONSTERS_SANS_SANS_BODY, 0 ; img, next
    ; ANIM_DATA_MONSTERS_TESTOBUG_ANIMS_BKG_1
    .byte 248, 0, 60, 0 ; x, y, delay, type
    .word IMG_DATA_MONSTERS_TESTOBUG_ANIMS_BKG_1, ANIM_DATA_MONSTERS_TESTOBUG_ANIMS_BKG_2 ; img, next
    ; ANIM_DATA_MONSTERS_TESTOBUG_ANIMS_BKG_2
    .byte 248, 0, 60, 0 ; x, y, delay, type
    .word IMG_DATA_MONSTERS_TESTOBUG_ANIMS_BKG_2, ANIM_DATA_MONSTERS_TESTOBUG_ANIMS_BKG_1 ; img, next

; anim_data_bkg_cl
    ; ANIM_DATA_MONSTERS_ATKIMG_L
    .byte 0, 0, 0, 0 ; x, y, delay, type
    .word IMG_CL_DATA_MONSTERS_ATK_IMG_LEFT, 0 ; img, next
    ; ANIM_DATA_MONSTERS_ATKIMG_R
    .byte 112, 0, 0, 0 ; x, y, delay, type
    .word IMG_CL_DATA_MONSTERS_ATK_IMG_RIGHT, 0 ; img, next
    ; ANIM_DATA_MONSTERS_UNDERTALE_LOGO_L
    .byte 0, 0, 0, 0 ; x, y, delay, type
    .word IMG_CL_DATA_MONSTERS_UNDERTALE_LOGO_LEFT, 0 ; img, next
    ; ANIM_DATA_MONSTERS_UNDERTALE_LOGO_R
    .byte 80, 0, 0, 0 ; x, y, delay, type
    .word IMG_CL_DATA_MONSTERS_UNDERTALE_LOGO_RIGHT, 0 ; img, next

; anim_data_spr
    ; ANIM_DATA_MONSTERS_EMBER_EMBER_SPARK
    .byte 0, 0, 255, 1 ; x, y, delay, type
    .word IMG_DATA_MONSTERS_EMBER_EMBER_SPARK, 0 ; img, next
    ; ANIM_DATA_MONSTERS_FROGGIT_FROGGIT_SIT
    .byte 0, 0, 255, 1 ; x, y, delay, type
    .word IMG_DATA_MONSTERS_FROGGIT_FROGGIT_SIT, 0 ; img, next
    ; ANIM_DATA_MONSTERS_FROGGIT_FROGGIT_JUMP
    .byte 0, 0, 255, 1 ; x, y, delay, type
    .word IMG_DATA_MONSTERS_FROGGIT_FROGGIT_JUMP, 0 ; img, next
    ; ANIM_DATA_MONSTERS_FROGGIT_FROGGIT_FLY
    .byte 0, 0, 255, 1 ; x, y, delay, type
    .word IMG_DATA_MONSTERS_FROGGIT_FROGGIT_FLY, 0 ; img, next
    ; ANIM_DATA_MONSTERS_SANS_SANS_BONE8
    .byte 0, 0, 255, 1 ; x, y, delay, type
    .word IMG_DATA_MONSTERS_SANS_SBONE_8, 0 ; img, next
    ; ANIM_DATA_MONSTERS_SANS_SANS_BONE16
    .byte 0, 0, 255, 1 ; x, y, delay, type
    .word IMG_DATA_MONSTERS_SANS_SBONE_16, 0 ; img, next
    ; ANIM_DATA_MONSTERS_SANS_SANS_BONE24
    .byte 0, 0, 255, 1 ; x, y, delay, type
    .word IMG_DATA_MONSTERS_SANS_SBONE_24, 0 ; img, next
    ; ANIM_DATA_MONSTERS_SANS_SANS_BONE32
    .byte 0, 0, 255, 1 ; x, y, delay, type
    .word IMG_DATA_MONSTERS_SANS_SBONE_32, 0 ; img, next
    ; ANIM_DATA_MONSTERS_SANS_SANS_BONEH
    .byte 0, 0, 255, 1 ; x, y, delay, type
    .word IMG_DATA_MONSTERS_SANS_SBONE_H, 0 ; img, next
    ; ANIM_DATA_MONSTERS_STRIKE_STRIKE_1
    .byte 248, 24, 8, 1 ; x, y, delay, type
    .word IMG_DATA_MONSTERS_STRIKE_STRIKE1, ANIM_DATA_MONSTERS_STRIKE_STRIKE_2 ; img, next
    ; ANIM_DATA_MONSTERS_STRIKE_STRIKE_2
    .byte 248, 24, 8, 1 ; x, y, delay, type
    .word IMG_DATA_MONSTERS_STRIKE_STRIKE2, ANIM_DATA_MONSTERS_STRIKE_STRIKE_3 ; img, next
    ; ANIM_DATA_MONSTERS_STRIKE_STRIKE_3
    .byte 248, 24, 8, 1 ; x, y, delay, type
    .word IMG_DATA_MONSTERS_STRIKE_STRIKE3, ANIM_DATA_MONSTERS_STRIKE_STRIKE_4 ; img, next
    ; ANIM_DATA_MONSTERS_STRIKE_STRIKE_4
    .byte 248, 24, 8, 1 ; x, y, delay, type
    .word IMG_DATA_MONSTERS_STRIKE_STRIKE4, ANIM_DATA_MONSTERS_STRIKE_STRIKE_5 ; img, next
    ; ANIM_DATA_MONSTERS_STRIKE_STRIKE_5
    .byte 248, 24, 8, 1 ; x, y, delay, type
    .word IMG_DATA_MONSTERS_STRIKE_STRIKE5, ANIM_DATA_MONSTERS_STRIKE_STRIKE_6 ; img, next
    ; ANIM_DATA_MONSTERS_STRIKE_STRIKE_6
    .byte 248, 24, 8, 1 ; x, y, delay, type
    .word IMG_DATA_MONSTERS_STRIKE_STRIKE6, 0 ; img, next
    ; ANIM_DATA_MONSTERS_TESTOBUG_ANIMS_SPR_0
    .byte 20, 8, 10, 1 ; x, y, delay, type
    .word IMG_DATA_MONSTERS_TESTOBUG_ANIMS_SPR, ANIM_DATA_MONSTERS_TESTOBUG_ANIMS_SPR_1 ; img, next
    ; ANIM_DATA_MONSTERS_TESTOBUG_ANIMS_SPR_1
    .byte 20, 8, 10, 1 ; x, y, delay, type
    .word IMG_DATA_MONSTERS_TESTOBUG_ANIMS_SPR_V, ANIM_DATA_MONSTERS_TESTOBUG_ANIMS_SPR_0 ; img, next
