start:
    ; song 100 = MEGALOVANIA
    LDX #100
    JSR play_music
    set_menu_dialog TXT_SANS_START
    mov player_soul, #SOUL::MENU
    JSR switch_player_soul

    display_anim ANIM_DATA_MONSTERS_SANS_SANS_BKG

    sta_ptr tmp+2, sans_act_txt
    JSR init_monster_act

    LDX cur_monster_fight_pos
    LDA #$00
    STA monster_flags, X
    STA sans_turns
    STA sans_glide
    STA sans_off

    JSR get_var_idx
    LDA #$00
    STA monster_vars+0, X
    STA monster_vars+1, X
    STA monster_vars+2, X
    STA monster_vars+3, X
    STA monster_vars+4, X
    STA monster_vars+5, X
    JMP clear_event

turn:
    @state = monster_vars+0
    @time = monster_vars+1
    @sp = monster_vars+3
    @att = monster_vars+4
    @cnt = monster_vars+5

    LDA cur_monster_fight_pos
    BEQ :+
    JMP @end_event
:
    LDA #$00
    STA sans_strk
    JSR get_var_idx
    LDA @state, X
    BEQ @setup
    CMP #$01
    BEQ @wait
    JMP @attack

    @setup:
    INC @state, X
    LDA #$00
    STA @time, X
    STA @cnt, X
    STA @sp, X
    JSR clear_main_box
    JSR text_post_process
    mov player_soul, #SOUL::RED
    JSR switch_player_soul
    mov futur_box_pos_x1, #$40
    mov futur_box_pos_x2, #$C6
    RTS

    @wait:
    LDA dialogbox_anim_flag
    BNE @rts
    INC @state, X
    @rts:
    RTS

    @attack:
    LDA @att, X
    AND #$03
    BNE :+
    JMP @wave
:
    CMP #$01
    BNE :+
    JMP @blasters
:
    CMP #$02
    BNE :+
    JMP @bones
:
    JMP @hbones

    ; Attack 1: thin bones slide left, the gap between the top and bottom bones rises and falls
    @wave:
    LDA @time, X
    CMP #$8C
    BCS @wave_end
    LDA @sp, X
    BNE @wave_dec
    LDA #$09
    STA @sp, X
    LDY @cnt, X
    LDA sans_wave_top, Y
    STA sans_kind
    LDA #HITBOX::BONE_LEFT
    LDX #$B6
    LDY #$82
    JSR sans_spawn
    JSR get_var_idx
    LDY @cnt, X
    LDA sans_wave_bot, Y
    STA sans_kind
    TAY
    LDA #$BC
    SEC
    SBC sans_bone_h, Y
    TAY
    LDA #HITBOX::BONE_LEFT
    LDX #$B6
    JSR sans_spawn
    JSR get_var_idx
    INC @cnt, X
    LDA @cnt, X
    CMP #$06
    BCC @wave_end
    LDA #$00
    STA @cnt, X
    JMP @wave_end
    @wave_dec:
    DEC @sp, X
    @wave_end:
    LDA @time, X
    CMP #$D2
    BCC :+
    JMP @finish
:
    JMP @tick

    ; Attack 2: a beam ring around the middle, then an X shaped beam
    @blasters:
    LDA @time, X
    BNE :+
    JMP @b_warn1
:
    CMP #$18
    BNE :+
    JMP @b_fire1
:
    CMP #$2C
    BEQ @b_clear
    CMP #$32
    BNE :+
    JMP @b_warn2
:
    CMP #$4A
    BNE :+
    JMP @b_fire2
:
    CMP #$5E
    BEQ @b_clear
    CMP #$64
    BCC :+
    JMP @finish
:
    JMP @tick
    @b_clear:
    JSR clear_hitbox
    JSR sans_erase
    JMP @tick
    @b_warn1:
    LDX #SANS_RING
    LDA #$00
    BEQ @b_warn
    @b_warn2:
    LDX #SANS_CROSS
    @b_warn:
    LDA #$F0
    STA tmp+6
    LDA #$00
    STA tmp+10
    JSR sans_rects_run
    JMP @tick
    @b_fire1:
    LDX #SANS_RING
    BEQ @b_fire
    @b_fire2:
    LDX #SANS_CROSS
    @b_fire:
    LDA #$F8
    STA tmp+6
    LDA #$01
    STA tmp+10
    JSR sans_rects_run
    JMP @tick

    ; Attack 3: thin bones slide left one at a time, alternating top and bottom
    @bones:
    LDA @time, X
    CMP #$8C
    BCS @bones_end
    LDA @sp, X
    BNE @bones_dec
    LDA #$11
    STA @sp, X
    LDA #$03
    STA sans_kind
    LDA @cnt, X
    LSR
    BCS :+
    LDA #HITBOX::BONE_LEFT
    LDX #$B6
    LDY #$82
    JSR sans_spawn
    JSR get_var_idx
    JMP :++
    :
    LDA #HITBOX::BONE_LEFT
    LDX #$B6
    LDY #$BC
    TYA
    SEC
    SBC sans_bone_h+3
    TAY
    LDA #HITBOX::BONE_LEFT
    JSR sans_spawn
    JSR get_var_idx
    :
    INC @cnt, X
    JMP @wave_end
    @bones_dec:
    DEC @sp, X
    @bones_end:
    LDA @time, X
    CMP #$D2
    BCC :+
    JMP @finish
:
    JMP @tick

    ; Attack 4: long bones lying on their side fall from the left half, then the right half
    @hbones:
    LDA @time, X
    CMP #$8C
    BCS @hbones_end
    LDA @sp, X
    BNE @hbones_dec
    LDA #$11
    STA @sp, X
    LDA #$04
    STA sans_kind
    LDA @cnt, X
    AND #$01
    TAY
    LDA sans_hbone_x, Y
    TAX
    LDY #$82
    LDA #HITBOX::BONE_FALL
    JSR sans_spawn
    JSR get_var_idx
    INC @cnt, X
    JMP @hbones_end
    @hbones_dec:
    DEC @sp, X
    @hbones_end:
    LDA @time, X
    CMP #$D2
    BCC :+
    JMP @finish
:
    JMP @tick

    @tick:
    JSR get_var_idx
    INC @time, X
    RTS

    @finish:
    JSR get_var_idx
    LDA #$00
    STA @state, X
    INC @att, X
    ; after the 22 dodged strikes, Sans offers the last chance to spare
    LDA sans_turns
    CMP #22
    BCC :+
    set_menu_dialog TXT_SANS_DROP
    JSR get_var_idx
:
    mov futur_box_pos_x1, #$08
    mov futur_box_pos_x2, #$F6
    mov player_soul, #SOUL::MENU
    JSR switch_player_soul
    JSR clear_hitbox
    @end_event:
    JMP clear_event

SANS_RING = 0
SANS_CROSS = 17

sans_wave_top: .byte 0, 1, 2, 3, 2, 1
sans_wave_bot: .byte 3, 2, 1, 0, 1, 2
sans_bone_h: .byte 8, 16, 24, 32
sans_fall_x: .byte $49, $90, $6B, $B4
sans_hbone_x: .byte $42, $86
sans_w: .byte 6, 6, 6, 6, 64
sans_h: .byte 8, 16, 24, 32, 6
sans_alo:
    .byte <ANIM_DATA_MONSTERS_SANS_SANS_BONE8, <ANIM_DATA_MONSTERS_SANS_SANS_BONE16, <ANIM_DATA_MONSTERS_SANS_SANS_BONE24
    .byte <ANIM_DATA_MONSTERS_SANS_SANS_BONE32, <ANIM_DATA_MONSTERS_SANS_SANS_BONEH
sans_ahi:
    .byte >ANIM_DATA_MONSTERS_SANS_SANS_BONE8, >ANIM_DATA_MONSTERS_SANS_SANS_BONE16, >ANIM_DATA_MONSTERS_SANS_SANS_BONE24
    .byte >ANIM_DATA_MONSTERS_SANS_SANS_BONE32, >ANIM_DATA_MONSTERS_SANS_SANS_BONEH

; beam shapes inside the box (15 x 6 tiles): column, row, width, height
sans_rects:
    ; ring: the middle is safe
    .byte 0, 0, 15, 2
    .byte 0, 4, 15, 2
    .byte 0, 2, 4, 2
    .byte 11, 2, 4, 2
    .byte $FF
    ; X: the four triangles are safe
    .byte 0, 0, 3, 1
    .byte 12, 0, 3, 1
    .byte 1, 1, 5, 1
    .byte 9, 1, 5, 1
    .byte 4, 2, 7, 2
    .byte 1, 4, 5, 1
    .byte 9, 4, 5, 1
    .byte 0, 5, 3, 1
    .byte 12, 5, 3, 1
    .byte $FF

; X = first rect, tmp+6 = tile, tmp+10 = 1 to add hitboxes: draws the beam rects
sans_rects_run:
    STX sans_off
    @next:
    LDX sans_off
    LDA sans_rects, X
    CMP #$FF
    BEQ @done
    STA tmp+11
    LDA sans_rects+1, X
    STA tmp+12
    LDA sans_rects+2, X
    STA tmp+13
    LDA sans_rects+3, X
    STA tmp+14
    LDA #$00
    STA tmp+7
    LDA tmp+11
    CLC
    ADC #$09
    TAX
    LDA tmp+12
    CLC
    ADC #$11
    TAY
    LDA tmp+13
    STA tmp+2
    LDA tmp+14
    STA tmp+3
    JSR sans_fill
    LDA tmp+10
    BEQ :+
    JSR sans_rect_hitbox
:
    LDA sans_off
    CLC
    ADC #$04
    STA sans_off
    JMP @next
    @done:
    RTS

; hitbox of the rect in tmp+11..14 (a bit smaller than the drawing)
sans_rect_hitbox:
    LDA tmp+11
    ASL
    ASL
    ASL
    CLC
    ADC #72
    LDX tmp+11
    BNE :+
    LDA #64
:
    SEC
    SBC #4
    STA sans_x
    LDA tmp+12
    ASL
    ASL
    ASL
    CLC
    ADC #136
    LDX tmp+12
    BNE :+
    LDA #128
:
    SEC
    SBC #4
    STA sans_y
    LDA tmp+11
    CLC
    ADC tmp+13
    ASL
    ASL
    ASL
    CLC
    ADC #72
    CMP #192
    BCC :+
    LDA #200
:
    SEC
    SBC #3
    STA tmp+4
    LDA tmp+12
    CLC
    ADC tmp+14
    ASL
    ASL
    ASL
    CLC
    ADC #136
    CMP #184
    BCC :+
    LDA #192
:
    SEC
    SBC #3
    STA tmp+5
    LDX sans_x
    LDY sans_y
    LDA #HITBOX::BLOCK
    JSR new_hitbox
    CPY #$FF
    BEQ :+
    LDA tmp+4
    STA hitbox_w, Y
    LDA tmp+5
    STA hitbox_h, Y
:
    RTS

; wipes the beams out of the box
sans_erase:
    LDA #$00
    STA tmp+6
    LDA #UI_CHR_BNK
    STA tmp+7
    LDX #$09
    LDY #$11
    LDA #$0F
    STA tmp+2
    LDA #$06
    STA tmp+3
    ; fall through

; X,Y = first tile, tmp+2 = width, tmp+3 = height, tmp+6 = tile, tmp+7 = tile info
; same as clear_inside_box, with any tile
sans_fill:
    @ppu = tmp+0
    @w = tmp+2
    @h = tmp+3
    @packet = tmp+4
    mov_ptr @packet, packet_buffer_end
    JSR xytile_2_ppu
    for_x @line, @h
        LDY #$00
        LDA @w
        ORA #$40
        STA (@packet), Y
        INY
        LDA @ppu+1
        STA (@packet), Y
        INY
        LDA @ppu+0
        STA (@packet), Y
        INY
        TYA
        add_A2ptr @packet
        add_A2ptr @ppu, #$20
        LDA tmp+6
        for_y @lo, #0
            STA (@packet), Y
        to_y_inc @lo, @w
        TYA
        add_A2ptr @packet
        LDA tmp+7
        for_y @hi, #0
            STA (@packet), Y
        to_y_inc @hi, @w
        TYA
        add_A2ptr @packet
    to_x_dec @line, #0
    mov_ptr packet_buffer_end, @packet
    RTS

; A = hitbox type, X = x, Y = y, sans_kind = anim kind; returns Y = hitbox idx
sans_spawn:
    STX sans_x
    STY sans_y
    LDX sans_x
    LDY sans_y
    JSR new_hitbox
    CPY #$FF
    BEQ @done
    LDX sans_kind
    LDA sans_w, X
    CLC
    ADC hitbox_x, Y
    STA hitbox_w, Y
    LDA sans_h, X
    CLC
    ADC hitbox_y, Y
    STA hitbox_h, Y
    LDA sans_alo, X
    STA tmp+0
    LDA sans_ahi, X
    STA tmp+1
    JSR add_anim
    CPX #$FF
    BNE :+
    LDA #$00
    STA hitbox_t, Y
    RTS
:
    INX
    TXA
    STA hitbox_a, Y
    TYA
    TAX
    LDA hitbox_a, X
    TAY
    DEY
    JSR shift_entity_spr
    @done:
    RTS

custom:
hit:
    JMP clear_event

act:
    @act_wait = monster_vars+2
    JSR get_var_idx
    LDA @act_wait, X
    BNE @wait
    INC @act_wait, X
    call_read_dialog TXT_SANS_CHECK
    RTS
    @wait:
    LDA n_dialog
    BNE @end
    JSR get_var_idx
    LDA #$00
    STA @act_wait, X
    JMP clear_event
    @end:
    RTS

item:
    JMP clear_event

spare:
    @spare_wait = monster_vars+2
    JSR get_var_idx
    LDA @spare_wait, X
    BNE @spare_wait_dialog
    LDA sans_turns
    CMP #22
    BCS @spare_win
    INC @spare_wait, X
    call_read_dialog TXT_SANS_SPARE_NOT_READY
    RTS
    @spare_wait_dialog:
    LDA n_dialog
    BNE @spare_end
    JSR get_var_idx
    LDA #$00
    STA @spare_wait, X
    JMP clear_event
    @spare_end:
    RTS
    @spare_win:
    LDA #$02
    JSR run_scene
    JMP begin_battle_victory

flee:
    JMP clear_event

sans_act_txt:
.byte $01
.byte FONT_CHR_BNK, "* Check", $00, "       "
