
update_hitboxes:
    LDA #<.bank(hitbox_call_table_move_lo)+$80
    STA MMC5_PRG_BNK1
    STA mmc5_banks+2

    ; for each hitbox
    for_x @loop, #MAX_HITBOX-1
        ; if hitbox inactive (type == 0)
        LDA hitbox_t, X
            ; continue
            BEQ @next

        ; call_hitbox_move(X)
        TAY
        phx
        JSR call_hitbox_move
        plx
        ; if hitbox link to animation
        LDA hitbox_a, X
        BEQ :+
            TAY
            DEY
            ; bones are made of several sprites: move them together
            LDA hitbox_t, X
            CMP #HITBOX::BONE_FALL
            BEQ @bone
            CMP #HITBOX::BONE_LEFT
            BNE @std
            @bone:
            JSR shift_entity_spr
            JMP :+
            @std:
            ; anim[Y].pos = hitbox[X].pos
            LDA hitbox_x, X
            STA anims_x, Y
            LDA hitbox_y, X
            STA anims_y, Y
            ;
            JSR update_entity_hitbox_pos
            ; falling hitboxes are only visible inside the box
            LDA hitbox_t, X
            CMP #HITBOX::FALL_DIAMOND
            BNE :+
                JSR clip_hitbox_spr
        :
        ; the hitbox may have been removed
        LDA hitbox_t, X
        BEQ @next
        ; if is_player_hit(X)
        JSR is_player_hit
        BNE @next
            LDA hitbox_t, X
            TAY
            ; call_hitbox_hit(X)
            phx
            JSR call_hitbox_hit
            plx
        @next:
    to_x_dec @loop, #-1

    RTS


; X = hitbox index, Y = anim index
; Move every sprite of the anim by the distance between the anim and the hitbox.
shift_entity_spr:
    LDA hitbox_x, X
    SEC
    SBC anims_x, Y
    STA tmp+0
    LDA hitbox_y, X
    SEC
    SBC anims_y, Y
    STA tmp+1
    LDA hitbox_x, X
    STA anims_x, Y
    LDA hitbox_y, X
    STA anims_y, Y
    INY
    STY tmp+2
    LDY #MAX_SPR-1
    @loop:
        LDA spr_buf_anim, Y
        CMP tmp+2
        BNE @next
            LDA spr_buf_x, Y
            CLC
            ADC tmp+0
            STA spr_buf_x, Y
            LDA spr_buf_y, Y
            CLC
            ADC tmp+1
            STA spr_buf_y, Y
        @next:
        DEY
        BPL @loop
    RTS


; X = hitbox index
; Place the sprites of a falling hitbox and clip them to the box.
sync_hitbox_spr:
    LDA hitbox_a, X
    TAY
    DEY
    JSR update_entity_hitbox_pos
    ; fall through


; X = hitbox index (type FALL_DIAMOND, linked to an 8x16 sprite)
; Hide the sprite while it is not fully inside the box,
; remove the hitbox once it went out through the bottom.
clip_hitbox_spr:
    ; bottom: y + 11 >= bound_y2 -> out
    LDA hitbox_y, X
    CLC
    ADC #11
    CMP player_bound_y2
    BCS @remove
    ; top: y + 4 < bound_y1 -> hidden
    LDA hitbox_y, X
    CLC
    ADC #4
    CMP player_bound_y1
    BCC @hide
    ; left: x + 4 < bound_x1 -> hidden
    LDA hitbox_x, X
    CLC
    ADC #4
    CMP player_bound_x1
    BCC @hide
    ; right: x + 3 >= bound_x2 -> hidden
    LDA hitbox_x, X
    CLC
    ADC #3
    CMP player_bound_x2
    BCS @hide
    RTS

    @hide:
    LDY #MAX_SPR-1
    :
        LDA spr_buf_anim, Y
        CMP hitbox_a, X
        BNE :+
            LDA #$FF
            STA spr_buf_y, Y
        :
        DEY
        BPL :--
    RTS

    @remove:
    JMP remove_hitbox


; X = hitbox index
; use A
is_player_hit:
    ; if player x >= hitbox_x[X]
    LDA player_x
    CMP hitbox_x, X
    blt :+
    ; and player x < hitbox_w[X]
    CMP hitbox_w, X
    bge :+
    ; and player y >= hitbox_y[X]
    LDA player_y
    CMP hitbox_y, X
    blt :+
    ; and player y < hitbox_h[X]
    CMP hitbox_h, X
    bge :+
        ; set Z
        LDA #$00
        RTS
    :
        ; clear Z
        LDA #$01
        RTS


call_hitbox_hit:
    LDA hitbox_call_table_hit_hi, Y
    PHA
    LDA hitbox_call_table_hit_lo, Y
    PHA
    RTS

call_hitbox_move:
    LDA hitbox_call_table_move_hi, Y
    PHA
    LDA hitbox_call_table_move_lo, Y
    PHA
    RTS


update_entity_hitbox_pos:
    INY
    STY tmp
    TYA
    for_y @loop, #MAX_SPR-1
        CMP spr_buf_anim, Y
        BNE :+
            LDA hitbox_x, X
            STA spr_buf_x, Y
            LDA hitbox_y, X
            STA spr_buf_y, Y
            LDA tmp
        :
    to_y_dec @loop, #-1
    RTS


; A = type
; X,Y = pos
; return Y = idx (-1=no idx)
new_hitbox:
    push_ay
    for_y @loop, #MAX_HITBOX-1
        LDA hitbox_t, Y
        BNE :+
            TXA
            STA hitbox_x, Y
            PLA
            STA hitbox_y, Y
            PLA
            STA hitbox_t, Y
            LDA #$00
            STA hitbox_a, Y
            RTS
        :
    to_y_dec @loop, #0
    PLA
    PLA
    DEY
    RTS


clear_hitbox:
    pushregs
    for_x @loop, #MAX_HITBOX-1
        LDA hitbox_t, X
        BEQ :+
            JSR remove_hitbox
        :
    to_x_dec @loop, #0
    pullregs
    RTS


; X = idx
remove_hitbox:
    LDA #$00
    STA hitbox_t, X
    LDA hitbox_a, X
    BEQ :+
        TAY
        DEY
        LDA #$00
        STA anims_flag, Y
        phx
        TYA
        JSR clear_entity_spr
        plx
    :
    RTS

; A kill gives a level; killing Froggit or Sans also shows a kill scene.
kill_reward:
    INC kill_lv
    ; fight 2 (Froggit) -> scene 1, fight 4 (Sans) -> scene 3
    LDA fight_id
    LSR
    BCS :+
    ASL
    SBC #$00
    BNE run_scene
:
    RTS

; Run a spare / kill picture scene from any bank context (A = scene_kind: 0 Froggit spare, 1 Froggit kill, 2 Sans spare, 3 Sans kill).
run_kill_scene:
    LDA #$01
    BNE run_scene
run_spare_scene:
    LDA #$00
run_scene:
    STA scene_kind
    LDA mmc5_banks+1
    PHA
    LDA mmc5_banks+2
    PHA
    LDA #<.bank(INIT)+$80
    STA mmc5_banks+1
    STA MMC5_PRG_BNK0
    LDA #<.bank(spare_scene_main)+$80
    STA mmc5_banks+2
    STA MMC5_PRG_BNK1
    JSR spare_scene_main
    PLA
    STA mmc5_banks+2
    STA MMC5_PRG_BNK1
    PLA
    STA mmc5_banks+1
    STA MMC5_PRG_BNK0
    RTS