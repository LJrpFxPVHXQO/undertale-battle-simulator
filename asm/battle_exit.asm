;--------------------------------
; Battle exit transition
;--------------------------------
;
; The NES cannot alpha blend an individual monster.  Fade the battle palette
; through a dim pass to black, then rebuild the encounter-selection screen.
;
; Win (spare or kill): Froggit -> Ember -> back to the landing page.
begin_battle_victory:
    LDA battle_exit_state
    BNE begin_battle_exit
    LDA fight_id
    CMP #$02
    BNE :+
        mov fight_id, #$03
        JMP begin_battle_exit
    :
    LDA #$00
    STA landing_done
    JMP begin_battle_exit

begin_battle_exit:
    LDA battle_exit_state
    BNE @end

    LDA #$01
    STA battle_exit_state
    LDA #$00
    STA battle_exit_timer
    STA n_dialog
    STA item_adr
    STA item_adr+1
    STA player_flag
    STA monster_0_event
    STA monster_1_event
    STA monster_2_event

    JSR clear_hitbox

    for_x @clear_anims, #MAX_ANIM-1
        LDA #$00
        STA anims_flag, X
    to_x_dec @clear_anims, #0

    mov player_soul, #SOUL::WAIT
@end:
    RTS


; Return A = 0 while normal battle processing may continue, nonzero otherwise.
update_battle_exit:
    LDA battle_exit_state
    BEQ @done

    INC battle_exit_timer
    LDA battle_exit_timer
    CMP #$08
    BCC @active

    LDA #$00
    STA battle_exit_timer
    INC battle_exit_state
    LDA battle_exit_state
    CMP #$02
    BEQ @dim
    CMP #$03
    BEQ @black
    CMP #$04
    BEQ @restart

@active:
    LDA #$01
    RTS

@dim:
    for_x @copy_dim, #$00
        LDA battle_exit_dim_palette, X
        STA palettes, X
    to_x_inc @copy_dim, #25
    JMP @send_palette

@black:
    for_x @copy_black, #$00
        LDA #$0F
        STA palettes, X
    to_x_inc @copy_black, #25

@send_palette:
    ora_adr nmi_flags, #NMI_PLT
    JMP @active

@restart:
    LDA #$00
    STA PPU_MASK
    JSR INIT
    LDA #$00
    STA battle_exit_state
    RTS

@done:
    LDA #$00
    RTS


battle_exit_dim_palette:
    .byte $0F
    .byte $10, $0F, $10
    .byte $0F, $10, $10
    .byte $06, $18, $10
    .byte $07, $0F, $0F
    .byte $10, $0F, $06
    .byte $06, $0F, $0F
    .byte $0F, $0F, $0F
    .byte $0F, $0F, $0F
