.segment "MONSTER_DATA"

hitbox_call_table_move_lo:
    .byte <(call_hitbox_none-1)
    .byte <(call_hitbox_move_diamond-1)
    .byte <(call_hitbox_move_fall-1)
    .byte <(call_hitbox_none-1)
    .byte <(call_hitbox_move_fly-1)
    .byte <(call_hitbox_move_bone_fall-1)
    .byte <(call_hitbox_move_bone_left-1)
    .byte <(call_hitbox_none-1)
    .byte <(call_hitbox_none-1)
.repeat 247
    .byte <(call_hitbox_none-1)
.endrepeat

hitbox_call_table_move_hi:
    .byte >(call_hitbox_none-1)
    .byte >(call_hitbox_move_diamond-1)
    .byte >(call_hitbox_move_fall-1)
    .byte >(call_hitbox_none-1)
    .byte >(call_hitbox_move_fly-1)
    .byte >(call_hitbox_move_bone_fall-1)
    .byte >(call_hitbox_move_bone_left-1)
    .byte >(call_hitbox_none-1)
    .byte >(call_hitbox_none-1)
.repeat 247
    .byte >(call_hitbox_none-1)
.endrepeat


hitbox_call_table_hit_lo:
    .byte <(call_hitbox_none-1)
    .byte <(call_hitbox_hit_diamond-1)
    .byte <(call_hitbox_hit_diamond-1)
    .byte <(call_hitbox_hit_diamond-1)
    .byte <(call_hitbox_hit_diamond-1)
    .byte <(call_hitbox_hit_diamond-1)
    .byte <(call_hitbox_hit_diamond-1)
    .byte <(call_hitbox_hit_diamond-1)
    .byte <(call_hitbox_none-1)
.repeat 247
    .byte <(call_hitbox_none-1)
.endrepeat

hitbox_call_table_hit_hi:
    .byte >(call_hitbox_none-1)
    .byte >(call_hitbox_hit_diamond-1)
    .byte >(call_hitbox_hit_diamond-1)
    .byte >(call_hitbox_hit_diamond-1)
    .byte >(call_hitbox_hit_diamond-1)
    .byte >(call_hitbox_hit_diamond-1)
    .byte >(call_hitbox_hit_diamond-1)
    .byte >(call_hitbox_hit_diamond-1)
    .byte >(call_hitbox_none-1)
.repeat 247
    .byte >(call_hitbox_none-1)
.endrepeat


call_hitbox_none:
    RTS


call_hitbox_move_diamond:
    LDA frame_counter
    LSR
    BCS @end

    LDA hitbox_x, X
    CMP player_x
    blt :+
        DEC hitbox_x, X
        DEC hitbox_w, X
        JMP :++
    :
        INC hitbox_x, X
        INC hitbox_w, X
    :

    LDA hitbox_y, X
    CMP player_y
    blt :+
        DEC hitbox_y, X
        DEC hitbox_h, X
        JMP :++
    :
        INC hitbox_y, X
        INC hitbox_h, X
    :

    @end:
    RTS


; moves toward the player every frame, but stands still while fly_pause is running
call_hitbox_move_fly:
    LDA fly_pause
    BNE @end
    ; half speed: move every other frame
    LDA frame_counter
    LSR
    BCS @end

    LDA hitbox_x, X
    CMP player_x
    blt :+
        DEC hitbox_x, X
        DEC hitbox_w, X
        JMP :++
    :
        INC hitbox_x, X
        INC hitbox_w, X
    :

    LDA hitbox_y, X
    CMP player_y
    blt :+
        DEC hitbox_y, X
        DEC hitbox_h, X
        JMP :++
    :
        INC hitbox_y, X
        INC hitbox_h, X
    :

    @end:
    RTS


call_hitbox_move_fall:
    INC hitbox_y, X
    INC hitbox_h, X
    RTS


call_hitbox_move_bone_fall:
    INC hitbox_y, X
    INC hitbox_h, X
    INC hitbox_y, X
    INC hitbox_h, X
    LDA hitbox_h, X
    CMP player_bound_y2
    BCC @end
    JMP remove_hitbox
    @end:
    RTS


call_hitbox_move_bone_left:
    DEC hitbox_x, X
    DEC hitbox_w, X
    DEC hitbox_x, X
    DEC hitbox_w, X
    LDA hitbox_x, X
    CMP player_bound_x1
    BCS @end
    JMP remove_hitbox
    @end:
    RTS


; damage by hitbox type: NONE, FOLLOW_DIAMOND, FALL_DIAMOND, FROG, FLY, BONE_FALL, BONE_LEFT, BLOCK, DECOR
hitbox_damage:
    .byte 0, 2, 2, 5, 1, 1, 1, 5, 0

; Y = hitbox type
call_hitbox_hit_diamond:
    LDA player_stats + PlayerStat::hp
    SEC
    SBC hitbox_damage, Y
    BCS :+
        LDA #$00
    :
    STA player_stats + PlayerStat::hp
    ora_adr player_flag, #PLAYER_FLAG_DRAW_HP
    JMP remove_hitbox


.segment "LAST_BNK"
