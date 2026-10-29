;--------------------------------
; Monster HP bars
;--------------------------------
;
; - menu_draw_hpbars: background bar next to each name in the FIGHT/ACT list
; - dmg_hpbar_update: sprite bar under the monster while the damage is shown
;

; X = monster stat offset (id << MONSTER_STAT_SHIFT)
; Load hpb_hp / hpb_max (low bytes, 255 if the value does not fit in a byte)
hpbar_load:
    LDA monster_stats + MonsterStat::hp+1, X
    BEQ @hp_lo
    LDA #$FF
    BNE @hp_set
@hp_lo:
    LDA monster_stats + MonsterStat::hp, X
@hp_set:
    STA hpb_hp
    LDA monster_stats + MonsterStat::maxhp+1, X
    BEQ @max_lo
    LDA #$FF
    BNE @max_set
@max_lo:
    LDA monster_stats + MonsterStat::maxhp, X
@max_set:
    STA hpb_max
    RTS


; Y = bar width in pixels
; return A = filled pixels = hpb_hp * Y / hpb_max (at least 1 if hp > 0)
hpbar_fill:
    LDA #$00
    STA hpb_acc+0
    STA hpb_acc+1
    STA hpb_cnt
    LDA hpb_max
    BEQ @end
@loop:
    LDA hpb_acc+0
    CLC
    ADC hpb_hp
    STA hpb_acc+0
    LDA hpb_acc+1
    ADC #$00
    STA hpb_acc+1
    BNE @sub
    LDA hpb_acc+0
    CMP hpb_max
    BCC @next
@sub:
    LDA hpb_acc+0
    SEC
    SBC hpb_max
    STA hpb_acc+0
    LDA hpb_acc+1
    SBC #$00
    STA hpb_acc+1
    INC hpb_cnt
@next:
    DEY
    BNE @loop
    LDA hpb_cnt
    BNE @end
    LDA hpb_hp
    BEQ @end
    INC hpb_cnt
@end:
    LDA hpb_cnt
    RTS


; Draw one bar per monster at the right of its name (list entries 3 to 5)
; Draw one bar per monster at the right of its name (list entry 3 + monster).
; Tile granularity: the green part uses palette 3, the red part palette 2.
menu_draw_hpbars:
    LDA n_monster
    STA hpb_i
@next_monster:
    DEC hpb_i
    BMI @done

    LDA hpb_i
    shift ASL, MONSTER_STAT_SHIFT
    TAX
    JSR hpbar_load
    LDY #10
    JSR hpbar_fill
    STA hpb_fill

    LDA hpb_i
    CLC
    ADC #3
    STA hpb_e

    ; start x: right after "* " + 8 letters + 1 space
    LDY hpb_i
    LDA menu_list_pos_x, Y
    CLC
    ADC #88
    STA hpb_x

    ; green part
    LDA hpb_fill
    BEQ @red
    STA hpb_t
    LDA #$C0
    STA hpb_cur
    LDA #$F0
    STA hpb_target
    JSR hpbar_run
@red:
    LDA #10
    SEC
    SBC hpb_fill
    BEQ @next_monster
    STA hpb_t
    LDA #$80
    STA hpb_cur
    LDA #$F8
    STA hpb_target
    JSR hpbar_run
    JMP @next_monster
@done:
    RTS


; Draw hpb_t tiles hpb_target with attribute hpb_cur at hpb_x, then advance hpb_x
hpbar_run:
    LDA hpb_e
    shift ASL, 4
    TAX
    LDA hpb_cur
    STA menu_list_str, X
    INX
    LDY hpb_t
@fill:
    LDA hpb_target
    STA menu_list_str, X
    INX
    DEY
    BNE @fill
    LDA #$00
    STA menu_list_str, X

    LDY hpb_i
    LDX hpb_e
    LDA hpb_x
    STA menu_list_pos_x, X
    LDA menu_list_pos_y, Y
    STA menu_list_pos_y, X
    JSR draw_menu_str

    ; hpb_x += hpb_t * 8
    LDA hpb_t
    ASL
    ASL
    ASL
    CLC
    ADC hpb_x
    STA hpb_x
    RTS

@done:
    RTS


HPBAR_SPR_W = 64
HPBAR_SPR_Y = 112

; Called every frame of the damage number phase
dmg_hpbar_update:
    LDA fight_timer
    CMP #FIGHT_STRICK_TIME
    BNE @step

    ; first frame: current and target widths
    LDA selected_monster
    shift ASL, MONSTER_STAT_SHIFT
    TAX
    JSR hpbar_load
    LDY #HPBAR_SPR_W
    JSR hpbar_fill
    STA hpb_cur
    LDA hpb_hp
    SEC
    SBC fight_damage
    BCS :+
        LDA #$00
    :
    STA hpb_hp
    LDY #HPBAR_SPR_W
    JSR hpbar_fill
    STA hpb_target

@step:
    ; slide down to the target after a short pause
    LDA fight_timer
    CMP #FIGHT_STRICK_TIME + 10
    BCC @draw
    LDA hpb_cur
    CMP hpb_target
    BEQ @draw
    BCC @draw
    SEC
    SBC #2
    BCC @snap
    CMP hpb_target
    BCS @store
@snap:
    LDA hpb_target
@store:
    STA hpb_cur

@draw:
    ; bar x = monster x - width / 2
    LDY selected_monster
    JSR monster_fightid_to_pos
    TXA
    SEC
    SBC #HPBAR_SPR_W / 2
    STA hpb_x
    LDA hpb_cur
    STA hpb_fill
    LDA #$00
    STA hpb_t
@spr:
    LDA hpb_fill
    CMP #8
    BCS @full
    LSR
    TAX
    LDA @partial, X
    LDY #$00
    STY hpb_fill
    BEQ @put
@full:
    SBC #8
    STA hpb_fill
    LDA #$36
@put:
    PHA
    LDA oam_size
    ASL
    ASL
    TAY
    LDA #HPBAR_SPR_Y - 1
    STA OAM+0, Y
    PLA
    STA OAM+1, Y
    LDA #$02
    STA OAM+2, Y
    LDA hpb_x
    STA OAM+3, Y
    CLC
    ADC #8
    STA hpb_x
    INC oam_size
    INC hpb_t
    LDA hpb_t
    CMP #HPBAR_SPR_W / 8
    BNE @spr
    RTS

; tiles for 0, 2, 4, 6 filled pixels
@partial:
    .byte $38, $3A, $3C, $3E
