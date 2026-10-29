start:
    ; song 53 = Stronger Monster
    LDX #53
    JSR play_music
    set_menu_dialog TXT_EMBER_START
    mov player_soul, #SOUL::MENU
    JSR switch_player_soul

    display_anim ANIM_DATA_MONSTERS_EMBER_EMBER_BKG

    sta_ptr tmp+2, ember_act_txt
    JSR init_monster_act

    LDX cur_monster_fight_pos
    LDA #$00
    STA monster_flags, X

    JSR get_var_idx
    LDA #$00
    STA monster_vars+0, X
    STA monster_vars+1, X
    STA monster_vars+2, X
    JMP clear_event

turn:
    @turn_state = monster_vars+0
    @turn_time = monster_vars+1

    LDA cur_monster_fight_pos
    BEQ :+
    JMP @end_event
:

    JSR get_var_idx
    LDA @turn_state, X
    CMP #$03
    BCC @setup
    JMP @wait_or_attack

    @setup:
    CLC
    ADC #$03
    STA @turn_state, X
    LDA #$2C
    STA @turn_time+0, X
    ; the sweep lasts exactly 256 frames so it starts at the left edge and wraps cleanly
    LDA @turn_state, X
    CMP #$03
    BNE :+
    LDA #$00
    STA @turn_time+0, X
:
    LDA #$01
    STA @turn_time+1, X
    JSR clear_main_box
    JSR text_post_process
    mov player_soul, #SOUL::RED
    JSR switch_player_soul
    mov futur_box_pos_x1, #$40
    mov futur_box_pos_x2, #$C6
    RTS

    @wait_or_attack:
    CMP #$06
    BCC @wait
    JMP @attack
    @wait:
    LDA dialogbox_anim_flag
    BEQ :+
    JMP @end
:
    LDA @turn_state, X
    CLC
    ADC #$03
    STA @turn_state, X
    RTS

    @attack:
    CMP #$06
    BEQ @cinder_drift
    CMP #$07
    BEQ @spark_fan

    ; Pattern 3: fast ash rain, three cinders per burst (the middle one lags behind).
    LDA @turn_time+0, X
    AND #$1F
    BNE @tick
    phx
    LDX #$48
    LDY #$70
    JSR ember_spawn
    LDX #$B8
    LDY #$70
    JSR ember_spawn
    LDX #$80
    LDY #$58
    JSR ember_spawn
    plx
    JMP @tick

    ; Pattern 1: one cinder at a time, the column sweeps left -> right -> left.
    @cinder_drift:
    LDA @turn_time+0, X
    AND #$07
    BNE @tick
    phx
    LDA @turn_time+0, X
    LSR
    LSR
    LSR
    ; triangle wave over 16 steps: 0..8 then 7..1, so each end column is hit once per pass
    AND #$0F
    CMP #$09
    BCC :+
    EOR #$0F
    CLC
    ADC #$01
:
    ; 9 columns, 14 px apart
    STA tmp+4
    ASL
    ASL
    ASL
    ASL
    SEC
    SBC tmp+4
    SBC tmp+4
    CLC
    ADC #$48
    TAX
    LDY #$70
    JSR ember_spawn
    plx
    JMP @tick
    ; Pattern 2: three cinders fall side by side.
    @spark_fan:
    LDA @turn_time+0, X
    AND #$3F
    BNE @tick
    phx
    LDX #$50
    LDY #$70
    JSR ember_spawn
    LDX #$80
    LDY #$60
    JSR ember_spawn
    LDX #$B0
    LDY #$70
    JSR ember_spawn
    plx
    @tick:
    dcx_16 @turn_time
    LDA @turn_time+1, X
    BNE @end
    LDA @turn_time+0, X
    BNE @end
    LDA @turn_state, X
    CMP #$08
    BEQ :+
    SEC
    SBC #$05
    STA @turn_state, X
    JMP @finish_turn
:
    LDA #$00
    STA @turn_state, X
    @finish_turn:
    mov futur_box_pos_x1, #$08
    mov futur_box_pos_x2, #$F6
    mov player_soul, #SOUL::MENU
    JSR switch_player_soul
    JSR clear_hitbox

    @end_event:
    JMP clear_event
    @end:
    RTS

; X = left x, Y = start y (above the box): spawns a cinder falling straight down
ember_spawn:
    LDA #HITBOX::FALL_DIAMOND
    JSR new_hitbox
    CPY #$FF
    BEQ @done
    TXA
    CLC
    ADC #$08
    STA hitbox_w, Y
    LDA hitbox_y, Y
    CLC
    ADC #$10
    STA hitbox_h, Y
    LDA #<ANIM_DATA_MONSTERS_EMBER_EMBER_SPARK
    STA tmp+0
    LDA #>ANIM_DATA_MONSTERS_EMBER_EMBER_SPARK
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
    ; place (and hide, if outside the box) the sprite right away
    TYA
    TAX
    JSR sync_hitbox_spr
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
    LDA act_choice
    BNE @listen
    call_read_dialog TXT_EMBER_CHECK
    RTS

    @listen:
    call_read_dialog TXT_EMBER_ACT_LISTEN
    ; flag bits 1-3 count the listens (up to 5); the 5th makes Ember spareable
    LDX cur_monster_fight_pos
    LDA monster_flags, X
    AND #$0E
    CMP #$0A
    BCS :+
    LDA monster_flags, X
    CLC
    ADC #$02
    STA monster_flags, X
    AND #$0E
    CMP #$0A
    BNE :+
    LDA monster_flags, X
    ORA #MONSTER_FLAG_SPARE
    STA monster_flags, X
:
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
    LDY cur_monster_fight_pos
    LDA monster_flags, Y
    AND #MONSTER_FLAG_SPARE
    BNE @spare_win
    INC @spare_wait, X
    call_read_dialog TXT_EMBER_SPARE_NOT_READY
    RTS
    @spare_wait_dialog:
    LDA n_dialog
    BNE @spare_end
    JSR get_var_idx
    LDA #$00
    STA @spare_wait, X
    JMP clear_event
    @spare_win:
    JMP begin_battle_victory
    @spare_end:
    RTS

flee:
    JMP clear_event

ember_act_txt:
.byte $02
.byte FONT_CHR_BNK, "* Check", $00, "       "
.byte FONT_CHR_BNK, "* Listen", $00, "      "
