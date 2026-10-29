m_1_start:
    ; song 9 = Enemy Approaching
    LDX #9
    JSR play_music
    set_menu_dialog TXT_FROGGIT_START
    mov player_soul ,  #SOUL::MENU
    JSR switch_player_soul

    display_anim ANIM_DATA_MONSTERS_FROGGIT_FROGGIT_BKG

    sta_ptr tmp+2 ,  froggit_act_txt
    JSR init_monster_act

    LDX cur_monster_fight_pos
    LDA #$00
    STA monster_flags ,  X

    JSR get_var_idx
    LDA #$00
    STA monster_vars+0 ,  X
    STA monster_vars+1 ,  X
    STA monster_vars+2 ,  X
    STA monster_vars+3 ,  X
    STA fly_pat

    JMP clear_event

m_1_turn:
    @turn_state = monster_vars+0
    @turn_time = monster_vars+1

    LDA cur_monster_fight_pos
    BEQ :+
    JMP @end_event
:

    JSR get_var_idx
    LDA @turn_state ,  X
    BNE @attack_wait

    LDA #$E0
    STA @turn_time+0 ,  X
    LDA #$01
    STA @turn_time+1 ,  X
    INC @turn_state ,  X
    LDA #$00
    STA monster_vars+6 ,  X
    STA fly_pause
    STA fly_count
    STA fly_t
    LDA fly_pat
    EOR #$01
    STA fly_pat
    BEQ :+
    LDA #$4A
    STA @turn_time+0 ,  X
:
    JSR clear_main_box
    JSR text_post_process
    mov player_soul ,  #SOUL::RED
    JSR switch_player_soul
    mov futur_box_pos_x1 ,  #$40
    mov futur_box_pos_x2 ,  #$C6
    RTS

    @attack_wait:
    CMP #$01
    BNE @attack
    LDA dialogbox_anim_flag
    BEQ :+
    RTS
:
    INC @turn_state ,  X
    RTS

    @attack:
    CMP #$02
    BEQ @attack_go
    CMP #$03
    BEQ @restore
    JMP @end_event
    @attack_go:
    phx
    LDA fly_pat
    BNE :+
    JSR frog_step
    JMP :++
:
    JSR fly_step
:
    plx

    @tick:
    dcx_16 @turn_time
    LDA @turn_time+1 ,  X
    BNE @end
    LDA @turn_time+0 ,  X
    BNE @end
    LDA #$00
    ; wait for the box to be full size again before giving the menu back
    LDA #$03
    STA @turn_state ,  X
    mov futur_box_pos_x1 ,  #$08
    mov futur_box_pos_x2 ,  #$F6
    JSR frog_kill
    JSR clear_hitbox
    RTS

    @restore:
    LDA player_bound_x1
    CMP #$08
    BNE @end
    LDA player_bound_x2
    CMP #$F6
    BNE @end
    LDA dialogbox_anim_flag
    BNE @end
    LDA #$00
    STA @turn_state ,  X
    mov player_soul ,  #SOUL::MENU
    JSR switch_player_soul

    @end_event:
    JMP clear_event
    @end:
    RTS

m_1_custom:
m_1_hit:
    JMP clear_event

m_1_act:
    @act_wait = monster_vars+2
    JSR get_var_idx
    LDA @act_wait ,  X
    BNE @wait
    INC @act_wait ,  X
    LDA act_choice
    BNE @compliment
    call_read_dialog TXT_FROGGIT_CHECK
    RTS

    @compliment:
    call_read_dialog TXT_FROGGIT_ACT_COMPLIMENT
    ; flag bits 1-3 count the compliments (up to 5); the 5th makes Froggit spareable
    LDX cur_monster_fight_pos
    LDA monster_flags ,  X
    AND #$0E
    CMP #$0A
    BCS :+
    LDA monster_flags ,  X
    CLC
    ADC #$02
    STA monster_flags ,  X
    AND #$0E
    CMP #$0A
    BNE :+
    LDA monster_flags ,  X
    ORA #MONSTER_FLAG_SPARE
    STA monster_flags ,  X
:
    RTS

    @wait:
    LDA n_dialog
    BNE @end
    JSR get_var_idx
    LDA #$00
    STA @act_wait ,  X
    JMP clear_event
    @end:
    RTS

m_1_item:
    JMP clear_event

m_1_spare:
    @spare_wait = monster_vars+2
    JSR get_var_idx
    LDA @spare_wait ,  X
    BNE @spare_wait_dialog
    LDY cur_monster_fight_pos
    LDA monster_flags ,  Y
    AND #MONSTER_FLAG_SPARE
    BNE @spare_win
    INC @spare_wait ,  X
    call_read_dialog TXT_FROGGIT_SPARE_NOT_READY
    RTS
    @spare_wait_dialog:
    LDA n_dialog
    BNE @spare_end
    JSR get_var_idx
    LDA #$00
    STA @spare_wait ,  X
    JMP clear_event
    @spare_win:
    JSR run_spare_scene
    JMP begin_battle_victory
    @spare_end:
    RTS

m_1_flee:
    JMP clear_event

froggit_act_txt:
.byte $02
.byte FONT_CHR_BNK ,  "* Check" ,  $00 ,  "       "
.byte FONT_CHR_BNK ,  "* Compliment" ,  $00 ,  "   "


FROG_SIT_TIME = 40
FROG_JUMP_TIME = 64
FROG_X = $AC

; parabola, peak 64 at the middle of the jump
frog_arc:
.repeat 65 ,  i
    .byte (i * (64 - i)) / 16
.endrepeat

; X = anim data idx (lo). Draw it and keep its slot in monster_vars+3
frog_show:
    STA tmp+0
    LDA #$00
    STA tmp+1
    JSR add_anim
    INX
    TXA
    PHA
    JSR get_var_idx
    PLA
    STA monster_vars+3 ,  X
    RTS

frog_remove_anim:
    JSR get_var_idx
    LDA monster_vars+3 ,  X
    BEQ @end
    TAY
    DEY
    LDA #$00
    STA monster_vars+3 ,  X
    STA anims_flag ,  Y
    TYA
    JSR clear_entity_spr
    @end:
    RTS

frog_kill:
    JSR frog_remove_anim
    JSR get_var_idx
    LDA monster_vars+4 ,  X
    TAY
    CPY #$FF
    BEQ @end
    LDA hitbox_t ,  Y
    CMP #HITBOX::FROG
    BNE @end
    LDA #$00
    STA hitbox_t ,  Y
    @end:
    LDA #$FF
    STA monster_vars+4 ,  X
    LDA #$00
    STA monster_vars+6 ,  X
    RTS

; tmp+0 = anim slot + 1, tmp+1 = x (left), tmp+2 = y (bottom row)
frog_place:
    LDA #$FF
    STA tmp+3
    LDA #$00
    STA tmp+4
    LDY #MAX_SPR-1
    @find:
        LDA spr_buf_anim ,  Y
        CMP tmp+0
        BNE :++
        LDA spr_buf_x ,  Y
        CMP tmp+3
        BCS :+
        STA tmp+3
    :
        LDA spr_buf_y ,  Y
        CMP tmp+4
        BCC :+
        STA tmp+4
    :
        DEY
        BPL @find
    LDA tmp+1
    SEC
    SBC tmp+3
    STA tmp+3
    LDA tmp+2
    SEC
    SBC tmp+4
    STA tmp+4
    LDY #MAX_SPR-1
    @move:
        LDA spr_buf_anim ,  Y
        CMP tmp+0
        BNE :+
        LDA spr_buf_x ,  Y
        CLC
        ADC tmp+3
        STA spr_buf_x ,  Y
        LDA spr_buf_y ,  Y
        CLC
        ADC tmp+4
        STA spr_buf_y ,  Y
    :
        DEY
        BPL @move
    RTS

; Called every frame during the attack: sit, then jump (low, medium or high)
frog_step:
    @anim = monster_vars+3
    @hb = monster_vars+4
    @t = monster_vars+5
    @mode = monster_vars+6
    @kind = monster_vars+7

    JSR get_var_idx
    LDA @mode ,  X
    CMP #$02
    BNE :+
    RTS
:
    LDA @anim ,  X
    BNE @tick
    JSR rng
    AND #$03
    CMP #$03
    BNE :+
    LDA #$01
:
    PHA
    JSR get_var_idx
    PLA
    STA @kind ,  X
    LDA #$00
    STA @t ,  X
    STA @mode ,  X
    LDA #$FF
    STA @hb ,  X
    LDA #ANIM_DATA_MONSTERS_FROGGIT_FROGGIT_SIT
    JSR frog_show
    LDA @anim ,  X
    BNE @tick
    RTS

    @tick:
    INC @t ,  X
    LDA @mode ,  X
    BNE @jump
    LDA @t ,  X
    CMP #FROG_SIT_TIME
    BCS @takeoff
    LDA #FROG_X
    STA tmp+1
    BNE @sit_y

    @takeoff:
    JSR frog_remove_anim
    JSR get_var_idx
    LDA #$01
    STA @mode ,  X
    LDA #$00
    STA @t ,  X
    LDA #ANIM_DATA_MONSTERS_FROGGIT_FROGGIT_JUMP
    JSR frog_show
    LDA @anim ,  X
    BNE :+
    RTS
:
    LDX #FROG_X
    LDY player_bound_y2
    LDA #HITBOX::FROG
    JSR new_hitbox
    TYA
    PHA
    JSR get_var_idx
    PLA
    STA @hb ,  X
    LDA #FROG_X
    STA tmp+1
    LDA #$00
    BEQ @set_y

    @sit_y:
    LDA #$00
    @set_y:
    STA tmp+5
    JMP @pos_y

    @jump:
    LDA @t ,  X
    CMP #FROG_JUMP_TIME
    BCC :+
    JSR frog_kill
    ; one jump per turn: end the turn shortly after landing
    LDA #$02
    STA @mode ,  X
    LDA #$1E
    STA monster_vars+1 ,  X
    LDA #$00
    STA monster_vars+2 ,  X
    RTS
:
    ASL
    STA tmp+7
    LDA #FROG_X
    SEC
    SBC tmp+7
    STA tmp+1
    LDY @t ,  X
    LDA frog_arc ,  Y
    STA tmp+5
    LDY @kind ,  X
    BEQ @low
    DEY
    BEQ @medium
    LDA tmp+5
    LSR
    LSR
    STA tmp+6
    LDA tmp+5
    SEC
    SBC tmp+6
    STA tmp+5
    JMP @pos_y
    @medium:
    LSR tmp+5
    JMP @pos_y
    @low:
    LSR tmp+5
    LSR tmp+5

    @pos_y:
    LDA player_bound_y2
    SEC
    SBC #18
    SEC
    SBC tmp+5
    STA tmp+2
    LDA @anim ,  X
    STA tmp+0
    JSR frog_place

    JSR get_var_idx
    LDA @hb ,  X
    TAY
    CPY #$FF
    BEQ @done
    LDA hitbox_t ,  Y
    CMP #HITBOX::FROG
    BNE @done
    LDA tmp+1
    CLC
    ADC #FROG_HIT_X
    STA hitbox_x ,  Y
    ADC #FROG_HIT_W
    STA hitbox_w ,  Y
    LDA tmp+2
    SEC
    SBC #FROG_HIT_Y
    STA hitbox_y ,  Y
    CLC
    ADC #FROG_HIT_H
    STA hitbox_h ,  Y
    @done:
    RTS

FROG_HIT_X = 2
FROG_HIT_W = 16
FROG_HIT_Y = 3
FROG_HIT_H = 16

FLY_MAX = 5
FLY_GAP = 30
FLY_PAUSE = 14

; X = 0, called every frame of the fly attack: a new fly every FLY_GAP frames, all flies freeze when it appears
fly_step:
    LDA fly_pause
    BEQ :+
    DEC fly_pause
:
    LDA fly_t
    BEQ :+
    DEC fly_t
    RTS
:
    LDA fly_count
    CMP #FLY_MAX
    BCS @end
    INC fly_count
    LDA #FLY_PAUSE
    STA fly_pause
    LDA #FLY_GAP
    STA fly_t
    JSR fly_spawn
    @end:
    RTS

fly_spawn:
    JSR rng
    AND #$3C
    ASL
    CLC
    ADC #$44
    TAX
    LDA player_bound_y1
    CLC
    ADC #$04
    TAY
    LDA #HITBOX::FLY
    JSR new_hitbox
    CPY #$FF
    BEQ @done
    TXA
    CLC
    ADC #$04
    STA hitbox_w ,  Y
    LDA hitbox_y ,  Y
    CLC
    ADC #$04
    STA hitbox_h ,  Y
    LDA #<ANIM_DATA_MONSTERS_FROGGIT_FROGGIT_FLY
    STA tmp+0
    LDA #>ANIM_DATA_MONSTERS_FROGGIT_FROGGIT_FLY
    STA tmp+1
    JSR add_anim
    CPX #$FF
    BNE :+
    LDA #$00
    STA hitbox_t ,  Y
    RTS
:
    INX
    TXA
    STA hitbox_a ,  Y
    TYA
    TAX
    LDA hitbox_a ,  X
    TAY
    DEY
    JSR update_entity_hitbox_pos
    @done:
    RTS
