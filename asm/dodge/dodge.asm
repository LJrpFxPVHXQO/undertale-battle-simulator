;################
; File: dodge
;################
; Soul Dodge: 6502 port of the DOS "soul_dodge.asm" mini-game.
;
; Survive timed obstacle rounds, then fight a boss (5 bosses in total).
; The arena is a 30x12 cell grid drawn with font glyphs; the soul is a sprite.
; Entered from the fight select screen ("3. Soul Dodge"), SELECT goes back.
;
; Entry point: dodge_main (called through run_soul_dodge, bank switched in
; the $A000 window).
;
; Controls: D-pad = move, A/B = shoot (bosses only), START = retry after the
;           game ended, SELECT = back to the fight select screen.

DODGE_FIGHT_ID = $FF

DD_W          = 30
DD_H          = 12
DD_BULLETS    = 32
DD_ROUND_BASE = 375
DD_UFO_SPAWN  = 125
DD_UFO_LIFE   = 63
DD_UFO_MOVE   = 4
DD_UFO_FIRE   = 15
DD_BOSS_W     = 9
DD_GRID_ROWS  = 22

; font glyph attribute bytes (CHR bank 0): white text / yellow text
DD_ATTR_WHITE  = FONT_CHR_BNK
DD_ATTR_YELLOW = FONT_CHR_BNK + $40
.assert FONT_CHR_BNK = $80, error, "dodge: attribute encoding expects FONT_CHR_BNK = $80"

; zero page scratch (tmp is free while the mini-game runs)
dd_p_new  = tmp+8
dd_p_shn  = tmp+10
dd_p_tile = tmp+12
dd_p_attr = tmp+14
dd_p_str  = tmp+6

;****************
; RAM
;****************
.segment "MMC5_RAM"

dd_grid_new:   .res 768
dd_grid_shown: .res 768

dd_zero_start:
dd_state:   .res 1  ; 0 = playing, 1 = won, 2 = dead
dd_boss:    .res 1  ; 0 = survival round, 1..5 = boss, 6 = all bosses beaten
dd_next:    .res 1  ; next boss / current round number (1..5)
dd_hp:      .res 1
dd_ticks:   .res 2
dd_round:   .res 2
dd_bx:      .res 1
dd_bdir:    .res 1
dd_bhp:     .res 1
dd_bmax:    .res 1
dd_flash:   .res 1
dd_bmc:     .res 1  ; boss move clock
dd_cool:    .res 1
dd_gap:     .res 1
dd_gs:      .res 1  ; gap start
dd_wcol:    .res 1
dd_sx:      .res 1  ; player shot
dd_sy:      .res 1
dd_fall:    .res 1
dd_spawn:   .res 1
dd_wave:    .res 1
dd_rc:      .res 1  ; heal pickup clock
dd_rx:      .res 1
dd_ry:      .res 1
dd_ul:      .res 1  ; ufo life
dd_ux:      .res 1
dd_uy:      .res 1
dd_udx:     .res 1
dd_udy:     .res 1
dd_um:      .res 1
dd_usx:     .res 1  ; ufo shot
dd_usy:     .res 1
dd_usc:     .res 1
dd_us:      .res 1  ; ufo spawn clock
dd_px:      .res 1
dd_py:      .res 1
dd_phase:   .res 1
dd_fc:      .res 1  ; frames until next tick
dd_cad:     .res 1
dd_hold:    .res 1
dd_prev:    .res 1
dd_color:   .res 1
dd_i:       .res 1
dd_j:       .res 1
dd_t:       .res 1
dd_secs:    .res 1
dd_total:   .res 1
dd_bul_x:   .res DD_BULLETS
dd_bul_y:   .res DD_BULLETS
dd_zero_end:

dd_rng:     .res 2
dd_ent:     .res 1

.segment "DODGE_BNK"

;****************
; Random numbers
;****************

; 16-bit xorshift (7,9,8). Returns A = low byte, X = high byte.
dd_rand:
    LDA dd_rng+0
    LSR
    STA tmp+4           ; low >> 1
    LDA #$00
    ROR                 ; (low & 1) << 7
    EOR dd_rng+0
    STA dd_rng+0
    LDA dd_rng+1
    LSR
    LDA #$00
    ROR                 ; (high & 1) << 7
    ORA tmp+4
    EOR dd_rng+1
    STA dd_rng+1
    LSR
    EOR dd_rng+0
    STA dd_rng+0
    LDA dd_rng+1
    EOR dd_rng+0
    STA dd_rng+1
    TAX
    LDA dd_rng+0
    RTS

; A = modulus (<= 127). Returns random 16-bit value % A in A.
dd_rand_mod:
    STA tmp+5
    JSR dd_rand
    STA tmp+6
    STX tmp+7
    LDA #$00
    LDX #16
    @loop:
        ASL tmp+6
        ROL tmp+7
        ROL
        CMP tmp+5
        BCC :+
        SBC tmp+5
        :
        DEX
        BNE @loop
    RTS

dd_hurt:
    LDA dd_hp
    BEQ :+
    DEC dd_hp
    :
    RTS

;****************
; Game logic
;****************

dd_clear_bullets:
    LDX #DD_BULLETS-1
    LDA #$FF
    :
        STA dd_bul_y, X
        DEX
        BPL :-
    RTS

dd_reset:
    LDA #$00
    LDX #(dd_zero_end - dd_zero_start - 1)
    :
        STA dd_zero_start, X
        DEX
        CPX #$FF
        BNE :-
    LDA #15
    STA dd_px
    LDA #9
    STA dd_py
    LDA #20
    STA dd_hp
    LDA #<DD_ROUND_BASE
    STA dd_round+0
    LDA #>DD_ROUND_BASE
    STA dd_round+1
    LDA #1
    STA dd_next
    STA dd_bdir
    LDA #10
    STA dd_bx
    LDA #4
    STA dd_gap
    LDA #$FF
    STA dd_sy
    STA dd_ry
    STA dd_usy
    JSR dd_clear_bullets
    LDA #5
    STA dd_fc
    ; mix some entropy into the generator, never leave it at 0
    LDA dd_rng+0
    EOR dd_ent
    STA dd_rng+0
    ORA dd_rng+1
    BNE :+
        LDA #1
        STA dd_rng+0
    :
    RTS

dd_start_survival:
    LDA #$00
    STA dd_boss
    STA dd_ticks+0
    STA dd_ticks+1
    STA dd_round+0
    STA dd_round+1
    LDX dd_next
    :
        CLC
        LDA dd_round+0
        ADC #<DD_ROUND_BASE
        STA dd_round+0
        LDA dd_round+1
        ADC #>DD_ROUND_BASE
        STA dd_round+1
        DEX
        BNE :-
    LDA #$00
    STA dd_spawn
    STA dd_wave
    STA dd_fall
    STA dd_rc
    STA dd_us
    STA dd_ul
    STA dd_um
    STA dd_usc
    LDA #$FF
    STA dd_ry
    STA dd_sy
    STA dd_usy
    JMP dd_clear_bullets

dd_setup_boss:
    LDX dd_boss
    LDA dd_t_health-1, X
    STA dd_bhp
    STA dd_bmax
    LDA dd_t_gap-1, X
    STA dd_gap
    LDA #10
    STA dd_bx
    LDA #1
    STA dd_bdir
    LDA #$00
    STA dd_bmc
    STA dd_flash
    STA dd_cool
    STA dd_fall
    STA dd_rc
    STA dd_ul
    STA dd_spawn
    STA dd_wave
    LDA #$FF
    STA dd_sy
    STA dd_ry
    STA dd_usy
    JMP dd_clear_bullets

dd_defeat_boss:
    LDA dd_boss
    CMP #5
    BCC :+
        LDA #20
        STA dd_hp
        LDA #6
        STA dd_boss
        LDA #1
        STA dd_state
        RTS
    :
    INC dd_next
    LDA #20
    STA dd_hp
    JMP dd_start_survival

dd_spawn_bullet:        ; A = column
    LDX #$00
    :
        LDY dd_bul_y, X
        CPY #$FF
        BEQ @store
        INX
        CPX #DD_BULLETS
        BCC :-
    RTS
    @store:
    STA dd_bul_x, X
    LDA #$00
    STA dd_bul_y, X
    RTS

dd_spawn_wave:
    LDA #(DD_W+1)
    SEC
    SBC dd_gap
    JSR dd_rand_mod
    STA dd_gs
    LDA #$00
    STA dd_wcol
    @col:
        LDA dd_wcol
        CMP dd_gs
        BCC @spawn
        SEC
        SBC dd_gs
        CMP dd_gap
        BCC @next
        @spawn:
        LDA dd_wcol
        JSR dd_spawn_bullet
        @next:
        INC dd_wcol
        LDA dd_wcol
        CMP #DD_W
        BCC @col
    RTS

dd_update_recovery:
    LDA dd_ry
    CMP #$FF
    BEQ @try
    CMP dd_py
    BNE @down
    LDA dd_rx
    CMP dd_px
    BNE @down
    LDA dd_hp
    CMP #20
    BCS @down
    LDA #$FF
    STA dd_ry
    LDA #$00
    STA dd_rc
    LDA dd_hp
    CMP #17
    BCS @max
    CLC
    ADC #3
    STA dd_hp
    RTS
    @max:
    LDA #20
    STA dd_hp
    RTS
    @down:
    INC dd_ry
    LDA dd_ry
    CMP #DD_H
    BCC @done
    LDA #$FF
    STA dd_ry
    LDA #$00
    STA dd_rc
    @done:
    RTS
    @try:
    INC dd_rc
    LDA dd_boss
    BNE @boss_rate
    LDA #100
    BNE @cmp
    @boss_rate:
    TAX
    LDA dd_t_recovery-1, X
    @cmp:
    STA tmp+4
    LDA dd_rc
    CMP tmp+4
    BCC @done
    LDA #$00
    STA dd_rc
    LDA #DD_W
    JSR dd_rand_mod
    STA dd_rx
    LDA #$00
    STA dd_ry
    RTS

dd_spawn_ufo:
    LDA #(DD_W-2)
    JSR dd_rand_mod
    STA dd_ux
    LDA #(DD_H-1)
    JSR dd_rand_mod
    STA dd_uy
    LDA #DD_UFO_LIFE
    STA dd_ul
    LDA #$00
    STA dd_um
    STA dd_usc
    LDA #$FF
    STA dd_usy
    JSR dd_rand
    AND #1
    STA dd_udx
    TXA
    AND #1
    STA dd_udy
    RTS

dd_move_ufo:
    INC dd_um
    LDA dd_um
    CMP #DD_UFO_MOVE
    BCS :+
        RTS
    :
    LDA #$00
    STA dd_um
    JSR dd_rand
    PHA
    AND #1
    STA dd_udx
    PLA
    LSR
    AND #1
    STA dd_udy
    ; horizontal
    LDA dd_udx
    BEQ @left
    LDA dd_ux
    CMP #(DD_W-3)
    BCS @bounce_l
    INC dd_ux
    JMP @vert
    @bounce_l:
    LDA #$00
    STA dd_udx
    DEC dd_ux
    JMP @vert
    @left:
    LDA dd_ux
    BEQ @bounce_r
    DEC dd_ux
    JMP @vert
    @bounce_r:
    LDA #1
    STA dd_udx
    INC dd_ux
    ; vertical
    @vert:
    LDA dd_udy
    BEQ @up
    LDA dd_uy
    CMP #(DD_H-2)
    BCS @bounce_u
    INC dd_uy
    RTS
    @bounce_u:
    LDA #$00
    STA dd_udy
    DEC dd_uy
    RTS
    @up:
    LDA dd_uy
    BEQ @bounce_d
    DEC dd_uy
    RTS
    @bounce_d:
    LDA #1
    STA dd_udy
    INC dd_uy
    RTS

dd_update_ufo_shot:
    LDA dd_usy
    CMP #$FF
    BEQ @try
    LDA dd_usx
    CMP dd_px
    BEQ @vert
    BCC @right
    DEC dd_usx
    JMP @vert
    @right:
    INC dd_usx
    @vert:
    LDA dd_usy
    CMP dd_py
    BEQ @hit
    BCC @down
    DEC dd_usy
    JMP @hit
    @down:
    INC dd_usy
    @hit:
    LDA dd_usy
    CMP dd_py
    BNE @end
    LDA dd_usx
    CMP dd_px
    BNE @end
    JSR dd_hurt
    LDA #$FF
    STA dd_usy
    LDA #$00
    STA dd_usc
    RTS
    @try:
    INC dd_usc
    LDA dd_usc
    CMP #DD_UFO_FIRE
    BCC @end
    LDA #$00
    STA dd_usc
    LDA dd_ux
    CLC
    ADC #1
    STA dd_usx
    LDA dd_uy
    CLC
    ADC #1
    STA dd_usy
    @end:
    RTS

dd_update_ufo:
    INC dd_us
    LDA dd_us
    CMP #DD_UFO_SPAWN
    BCC @check
    LDA #$00
    STA dd_us
    LDA dd_ul
    BNE @check
    JMP dd_spawn_ufo
    @check:
    LDA dd_ul
    BEQ @done
    DEC dd_ul
    BEQ @leave
    JSR dd_move_ufo
    JMP dd_update_ufo_shot
    @leave:
    LDA #$FF
    STA dd_usy
    @done:
    RTS

dd_update:
    LDA dd_boss
    CMP #6
    BCC @active
    RTS
    @active:
    LDA dd_boss
    BNE @boss_clock
    INC dd_ticks+0
    BNE @clock_done
    INC dd_ticks+1
    JMP @clock_done
    @boss_clock:
    LDA dd_cool
    BEQ @clock_done
    DEC dd_cool
    @clock_done:

    JSR dd_update_recovery

    LDA dd_boss
    BNE @no_ufo
    LDA dd_next
    CMP #4
    BCC @no_ufo
    JSR dd_update_ufo
    @no_ufo:

    LDA dd_boss
    BEQ @shot
    LDA dd_flash
    BEQ :+
    DEC dd_flash
    :
    INC dd_bmc
    LDX dd_boss
    LDA dd_bmc
    CMP dd_t_move-1, X
    BCC @shot
    LDA #$00
    STA dd_bmc
    LDA dd_bdir
    BEQ @move_left
    LDA dd_bx
    CMP #(DD_W-DD_BOSS_W)
    BCS @turn_left
    INC dd_bx
    JMP @shot
    @turn_left:
    LDA #$00
    STA dd_bdir
    JMP @shot
    @move_left:
    LDA dd_bx
    BEQ @turn_right
    DEC dd_bx
    JMP @shot
    @turn_right:
    LDA #1
    STA dd_bdir

    @shot:
    LDA dd_sy
    CMP #$FF
    BEQ @bullets
    CMP #$00
    BEQ @check_hit
    DEC dd_sy
    BNE @bullets
    @check_hit:
    LDA dd_sx
    CMP dd_bx
    BCC @miss
    LDA dd_bx
    CLC
    ADC #DD_BOSS_W
    STA tmp+4
    LDA dd_sx
    CMP tmp+4
    BCS @miss
    DEC dd_bhp
    LDA #5
    STA dd_flash
    LDA #$FF
    STA dd_sy
    LDA dd_bhp
    BNE @bullets
    JMP dd_defeat_boss
    @miss:
    LDA #$FF
    STA dd_sy

    @bullets:
    INC dd_fall
    LDX dd_next
    LDA dd_fall
    CMP dd_t_fall-1, X
    BCS @fall
    JMP @waves
    @fall:
    LDA #$00
    STA dd_fall
    LDX #(DD_BULLETS-1)
    @move:
        LDA dd_bul_y, X
        CMP #$FF
        BEQ @move_next
        INC dd_bul_y, X
        LDA dd_bul_y, X
        CMP #DD_H
        BCC @move_next
        LDA #$FF
        STA dd_bul_y, X
        @move_next:
        DEX
        BPL @move

    INC dd_spawn
    LDA dd_boss
    BNE @attack_rate
    LDX dd_next
    LDA dd_t_obs_spawn-1, X
    JMP @check_spawn
    @attack_rate:
    TAX
    LDA dd_t_attack-1, X
    @check_spawn:
    STA tmp+4
    LDA dd_spawn
    CMP tmp+4
    BCC @waves
    LDA #$00
    STA dd_spawn
    LDA #DD_W
    JSR dd_rand_mod
    JSR dd_spawn_bullet

    @waves:
    INC dd_wave
    LDA dd_boss
    BNE @boss_wave
    LDX dd_next
    LDA dd_t_obs_wave-1, X
    JMP @check_wave
    @boss_wave:
    TAX
    LDA dd_t_wave-1, X
    @check_wave:
    STA tmp+4
    LDA dd_wave
    CMP tmp+4
    BCC @collide
    LDA #$00
    STA dd_wave
    JSR dd_spawn_wave

    @collide:
    LDX #$00
    @col_loop:
        LDA dd_bul_y, X
        CMP #$FF
        BEQ @col_next
        CMP dd_py
        BNE @col_next
        LDA dd_bul_x, X
        CMP dd_px
        BNE @col_next
        LDA #$FF
        STA dd_bul_y, X
        JSR dd_hurt
        LDA dd_hp
        BEQ @col_done
        @col_next:
        INX
        CPX #DD_BULLETS
        BCC @col_loop
    @col_done:
    RTS

dd_tick:
    JSR dd_update
    LDA dd_hp
    BNE :+
        LDA #2
        STA dd_state
        RTS
    :
    LDA dd_state
    BNE @end
    LDA dd_boss
    BNE @end
    LDA dd_ticks+1
    CMP dd_round+1
    BCC @end
    BNE @begin
    LDA dd_ticks+0
    CMP dd_round+0
    BCC @end
    @begin:
    LDA dd_next
    STA dd_boss
    JSR dd_setup_boss
    @end:
    RTS

;****************
; Grid building
;****************

; A = row, X = col -> dd_p_new = &dd_grid_new[row*32 + col]
dd_cell_ptr:
    PHA
    AND #7
    ASL
    ASL
    ASL
    ASL
    ASL
    CLC
    ADC #<dd_grid_new
    STA dd_p_new
    LDA #>dd_grid_new
    ADC #0
    STA dd_p_new+1
    TXA
    CLC
    ADC dd_p_new
    STA dd_p_new
    BCC :+
    INC dd_p_new+1
    :
    PLA
    LSR
    LSR
    LSR
    CLC
    ADC dd_p_new+1
    STA dd_p_new+1
    RTS

; A = glyph, X = arena x, Y = arena y
dd_plot:
    STA tmp+4
    TYA
    CLC
    ADC #5
    INX
    JSR dd_cell_ptr
    LDA tmp+4
    LDY #0
    STA (dd_p_new), Y
    RTS

dd_putc:
    ORA dd_color
    STY tmp+5
    LDY #0
    STA (dd_p_new), Y
    LDY tmp+5
    INC dd_p_new
    BNE :+
    INC dd_p_new+1
    :
    RTS

dd_puts:                ; A/X = string address (zero terminated)
    STA dd_p_str+0
    STX dd_p_str+1
    LDY #0
    :
        LDA (dd_p_str), Y
        BEQ :+
        JSR dd_putc
        INY
        BNE :-
    :
    RTS

dd_dec3:                ; A = 0..255
    LDX #'0'
    :
        CMP #100
        BCC :+
        SBC #100
        INX
        BNE :-
    :
    PHA
    TXA
    JSR dd_putc
    PLA
dd_dec2:                ; A = 0..99
    LDX #'0'
    :
        CMP #10
        BCC :+
        SBC #10
        INX
        BNE :-
    :
    PHA
    TXA
    JSR dd_putc
    PLA
    CLC
    ADC #'0'
    JMP dd_putc

.macro DD_AT row, col
    LDA #row
    LDX #col
    JSR dd_cell_ptr
.endmacro

.macro DD_STR lbl
    LDA #<lbl
    LDX #>lbl
    JSR dd_puts
.endmacro

dd_border_row:
    LDY #31
    LDA #'+'
    STA (dd_p_new), Y
    LDY #0
    STA (dd_p_new), Y
    LDA #'='
    :
        INY
        STA (dd_p_new), Y
        CPY #30
        BNE :-
    RTS

dd_build_arena:
    ; clear
    LDA #<dd_grid_new
    STA dd_p_new+0
    LDA #>dd_grid_new
    STA dd_p_new+1
    LDX #3
    LDY #0
    LDA #0
    :
        STA (dd_p_new), Y
        INY
        BNE :-
        INC dd_p_new+1
        DEX
        BNE :-

    ; borders
    DD_AT 4, 0
    JSR dd_border_row
    DD_AT 17, 0
    JSR dd_border_row
    LDA #5
    STA dd_t
    :
        LDA dd_t
        LDX #0
        JSR dd_cell_ptr
        LDA #'|'
        LDY #0
        STA (dd_p_new), Y
        LDY #31
        STA (dd_p_new), Y
        INC dd_t
        LDA dd_t
        CMP #17
        BCC :-

    ; heal pickup
    LDA dd_ry
    CMP #$FF
    BEQ :+
        TAY
        LDX dd_rx
        LDA #('+' | $80)
        JSR dd_plot
    :

    ; bullets
    LDA #$00
    STA dd_i
    @bul:
        LDX dd_i
        LDA dd_bul_y, X
        CMP #$FF
        BEQ @bul_next
        TAY
        LDA dd_bul_x, X
        TAX
        LDA #'*'
        JSR dd_plot
        @bul_next:
        INC dd_i
        LDA dd_i
        CMP #DD_BULLETS
        BCC @bul

    ; ufo
    LDA dd_ul
    BEQ @no_ufo
        LDX dd_ux
        LDY dd_uy
        LDA #('<' | $80)
        JSR dd_plot
        LDX dd_ux
        INX
        LDY dd_uy
        LDA #('=' | $80)
        JSR dd_plot
        LDX dd_ux
        INX
        INX
        LDY dd_uy
        LDA #('>' | $80)
        JSR dd_plot
    @no_ufo:
    LDA dd_usy
    CMP #$FF
    BEQ :+
        TAY
        LDX dd_usx
        LDA #('!' | $80)
        JSR dd_plot
    :
    LDA dd_sy
    CMP #$FF
    BEQ :+
        TAY
        LDX dd_sx
        LDA #('^' | $80)
        JSR dd_plot
    :
    RTS

dd_build_text:
    LDA #$00
    STA dd_color

    ; row 0: title
    LDA dd_boss
    BNE @boss_title
        DD_AT 0, 5
        DD_STR dd_s_landing
        JMP @row1
    @boss_title:
    CMP #6
    BCC :+
    LDA #5
    :
    STA dd_t
    DD_AT 0, 8
    DD_STR dd_s_boss
    LDA dd_t
    CLC
    ADC #'0'
    JSR dd_putc
    DD_STR dd_s_boss2

    ; row 1: status
    @row1:
    LDA dd_boss
    BNE @boss_status
        DD_AT 1, 1
        DD_STR dd_s_lv
        LDA dd_hp
        JSR dd_dec2
        DD_STR dd_s_max
        LDA dd_hp
        CLC
        ADC #1
        LSR
        STA dd_t
        LDX #0
        @bar:
            STX dd_i
            LDA #'-'
            CPX dd_t
            BCS :+
            LDA #'#'
            :
            JSR dd_putc
            LDX dd_i
            INX
            CPX #10
            BCC @bar
        LDA #']'
        JSR dd_putc
        JMP @row2
    @boss_status:
    DD_AT 1, 1
    DD_STR dd_s_hp
    LDA dd_hp
    JSR dd_dec2
    DD_AT 1, 17
    DD_STR dd_s_bosshp
    LDA dd_bhp
    JSR dd_dec2
    LDA #'/'
    JSR dd_putc
    LDA dd_bmax
    JSR dd_dec2

    ; row 2: timer
    @row2:
    LDA dd_boss
    BNE @row3
    SEC
    LDA dd_round+0
    SBC dd_ticks+0
    STA tmp+6
    LDA dd_round+1
    SBC dd_ticks+1
    STA tmp+7
    ASL tmp+6
    ROL tmp+7
    CLC
    LDA tmp+6
    ADC #24
    STA tmp+6
    BCC :+
    INC tmp+7
    :
    LDX #0
    @div:
        LDA tmp+7
        BNE @sub
        LDA tmp+6
        CMP #25
        BCC @div_done
        @sub:
        SEC
        LDA tmp+6
        SBC #25
        STA tmp+6
        LDA tmp+7
        SBC #0
        STA tmp+7
        INX
        BNE @div
    @div_done:
    STX dd_secs
    LDA #0
    LDX dd_next
    :
        CLC
        ADC #30
        DEX
        BNE :-
    STA dd_total
    DD_AT 2, 1
    DD_STR dd_s_time
    LDA dd_secs
    JSR dd_dec3
    DD_STR dd_s_slash
    LDA dd_total
    JSR dd_dec3

    ; row 3: boss art
    @row3:
    LDA dd_boss
    BEQ @row18
    CMP #6
    BCS @row18
    LDA dd_boss
    SEC
    SBC #1
    ASL
    STA dd_t
    ASL
    ASL
    CLC
    ADC dd_t            ; (boss-1) * 10
    STA dd_t
    LDA #3
    LDX dd_bx
    INX
    JSR dd_cell_ptr
    LDA #$80
    STA dd_color
    LDA dd_flash
    BEQ @art
        DD_STR dd_s_hit
        JMP @art_done
    @art:
    LDA #<dd_art
    CLC
    ADC dd_t
    PHA
    LDA #>dd_art
    ADC #0
    TAX
    PLA
    JSR dd_puts
    @art_done:
    LDA #$00
    STA dd_color

    ; row 18: message
    @row18:
    DD_AT 18, 1
    LDA dd_state
    CMP #2
    BNE :+
        DD_STR dd_s_over
        JMP @hints
    :
    CMP #1
    BNE :+
        DD_STR dd_s_win
        JMP @hints
    :
    LDA dd_boss
    BEQ :+
        DD_STR dd_s_shoot
        JMP @hints
    :
    LDA dd_next
    CMP #4
    BCC :+
        DD_STR dd_s_ufo
        JMP @hints
    :
    DD_STR dd_s_survive

    @hints:
    DD_AT 19, 3
    DD_STR dd_s_hint1
    DD_AT 20, 3
    DD_STR dd_s_hint2
    RTS

;****************
; Diff / draw
;****************

; A = row -> dd_p_new / dd_p_shn at the start of that row
dd_row_ptrs:
    PHA
    AND #7
    ASL
    ASL
    ASL
    ASL
    ASL
    STA tmp+5
    PLA
    LSR
    LSR
    LSR
    STA tmp+4
    CLC
    LDA #<dd_grid_new
    ADC tmp+5
    STA dd_p_new+0
    LDA #>dd_grid_new
    ADC tmp+4
    STA dd_p_new+1
    CLC
    LDA #<dd_grid_shown
    ADC tmp+5
    STA dd_p_shn+0
    LDA #>dd_grid_shown
    ADC tmp+4
    STA dd_p_shn+1
    RTS

; A = row. Queues one packet covering the changed cells of this row.
dd_diff_row:
    STA tmp+0
    JSR dd_row_ptrs
    LDY #0
    :
        LDA (dd_p_new), Y
        CMP (dd_p_shn), Y
        BNE @first
        INY
        CPY #32
        BNE :-
    RTS
    @first:
    STY tmp+1
    LDY #31
    :
        LDA (dd_p_new), Y
        CMP (dd_p_shn), Y
        BNE @last
        DEY
        BPL :-
    @last:
    STY tmp+2
    TYA
    SEC
    SBC tmp+1
    CLC
    ADC #1
    STA tmp+3           ; count

    ; enough room for a full row packet?
    LDA packet_buffer_end+1
    CMP #>(packet_buffer+1981)
    BCC @room
    BNE @full
    LDA packet_buffer_end+0
    CMP #<(packet_buffer+1981)
    BCC @room
    BEQ @room
    @full:
    RTS
    @room:
    LDA packet_buffer_end+0
    STA dd_p_tile+0
    LDA packet_buffer_end+1
    STA dd_p_tile+1
    LDY #0
    LDA tmp+3
    STA (dd_p_tile), Y
    ; PPU address = $2020 + row*32 + first
    LDA tmp+0
    AND #7
    ASL
    ASL
    ASL
    ASL
    ASL
    CLC
    ADC #$20
    STA tmp+4
    LDA #0
    ADC #0
    STA tmp+5
    LDA tmp+4
    CLC
    ADC tmp+1
    STA tmp+4
    LDA tmp+5
    ADC #0
    STA tmp+5
    LDA tmp+0
    LSR
    LSR
    LSR
    CLC
    ADC tmp+5
    ADC #$20
    LDY #1
    STA (dd_p_tile), Y
    LDA tmp+4
    INY
    STA (dd_p_tile), Y
    ; tile data starts 3 bytes in, attribute data after the tiles
    CLC
    LDA dd_p_tile+0
    ADC #3
    STA dd_p_tile+0
    BCC :+
    INC dd_p_tile+1
    :
    CLC
    LDA dd_p_tile+0
    ADC tmp+3
    STA dd_p_attr+0
    LDA dd_p_tile+1
    ADC #0
    STA dd_p_attr+1
    CLC
    LDA dd_p_attr+0
    ADC tmp+3
    STA packet_buffer_end+0
    LDA dd_p_attr+1
    ADC #0
    STA packet_buffer_end+1
    ; move row pointers to the first changed cell
    CLC
    LDA dd_p_new+0
    ADC tmp+1
    STA dd_p_new+0
    BCC :+
    INC dd_p_new+1
    :
    CLC
    LDA dd_p_shn+0
    ADC tmp+1
    STA dd_p_shn+0
    BCC :+
    INC dd_p_shn+1
    :
    LDY #0
    @copy:
        LDA (dd_p_new), Y
        STA (dd_p_shn), Y
        PHA
        AND #$7F
        STA (dd_p_tile), Y
        PLA
        CMP #$80
        LDA #DD_ATTR_WHITE
        BCC :+
        LDA #DD_ATTR_YELLOW
        :
        STA (dd_p_attr), Y
        INY
        CPY tmp+3
        BNE @copy
    RTS

; A = first row, X = last row
dd_diff_range:
    STA dd_i
    STX dd_j
    :
        LDA dd_i
        JSR dd_diff_row
        INC dd_i
        LDA dd_i
        CMP dd_j
        BCC :-
        BEQ :-
    RTS

.macro DD_ADD32 ptr
    CLC
    LDA ptr
    ADC #32
    STA ptr
    BCC :+
    INC ptr+1
    :
.endmacro

; Draws the whole grid with rendering disabled and restarts rendering.
dd_blit_all:
    LDA #$00
    STA PPU_MASK
    LDA #NMI_DONE
    STA nmi_flags
    LDA #$00
    STA scroll_x
    STA scroll_y

    ; wipe the attribute RAM (mode 2 = plain RAM)
    LDA #$02
    STA MMC5_EXT_RAM
    LDA #$00
    TAX
    :
        STA MMC5_EXP_RAM+$000, X
        STA MMC5_EXP_RAM+$100, X
        STA MMC5_EXP_RAM+$200, X
        STA MMC5_EXP_RAM+$300, X
        INX
        BNE :-
    JSR clear_nt_all_raw

    LDA ppu_ctrl_val
    AND #($FF - PPU_CTRL_INC)
    STA PPU_CTRL
    BIT PPU_STATUS
    LDA #$20
    STA PPU_ADDR
    STA PPU_ADDR

    LDA #<dd_grid_new
    STA dd_p_new+0
    LDA #>dd_grid_new
    STA dd_p_new+1
    LDA #<dd_grid_shown
    STA dd_p_shn+0
    LDA #>dd_grid_shown
    STA dd_p_shn+1
    LDA #<(MMC5_EXP_RAM+$20)
    STA dd_p_tile+0
    LDA #>(MMC5_EXP_RAM+$20)
    STA dd_p_tile+1
    LDA #DD_GRID_ROWS
    STA dd_i
    @row:
        LDY #0
        @col:
            LDA (dd_p_new), Y
            STA (dd_p_shn), Y
            PHA
            AND #$7F
            STA PPU_DATA
            PLA
            CMP #$80
            LDA #DD_ATTR_WHITE
            BCC :+
            LDA #DD_ATTR_YELLOW
            :
            STA (dd_p_tile), Y
            INY
            CPY #32
            BNE @col
        DD_ADD32 dd_p_new
        DD_ADD32 dd_p_shn
        DD_ADD32 dd_p_tile
        DEC dd_i
        BNE @row

    LDA #$01
    STA MMC5_EXT_RAM

    ; yellow text uses background palette 3
    LDA #$28
    STA palettes+10
    STA palettes+11
    STA palettes+12

    LDA #<packet_buffer
    STA packet_buffer_end+0
    LDA #>packet_buffer
    STA packet_buffer_end+1
    LDA #$00
    STA packet_buffer_counter+0
    STA packet_buffer_counter+1
    STA background_index
    STA background+0

    LDA #(PPU_MASK_BKG+PPU_MASK_BKG8+PPU_MASK_SPR+PPU_MASK_SPR8)
    STA PPU_MASK
    LDA #(NMI_PLT+NMI_SPR+NMI_SCRL+NMI_BKG)
    STA nmi_flags
    RTS

dd_start_screen:
    LDA #$00
    STA PPU_MASK
    LDA #NMI_DONE
    STA nmi_flags
    JSR dd_reset
    JSR dd_build_arena
    JSR dd_build_text
    JMP dd_blit_all

;****************
; Input
;****************

dd_input:
    LDA btn_1
    AND #$0F
    BNE @dirs
    STA dd_hold
    STA dd_prev
    JMP @fire
    @dirs:
    CMP dd_prev
    BEQ @held
        STA dd_prev
        LDA dd_rng+0
        EOR dd_ent
        STA dd_rng+0
        LDA #9
        STA dd_hold
        JMP @move
    @held:
    DEC dd_hold
    BNE @fire
    LDA #3
    STA dd_hold

    @move:
    LDA btn_1
    AND #BTN_LEFT
    BEQ :+
        LDA dd_px
        BEQ :+
        DEC dd_px
    :
    LDA btn_1
    AND #BTN_RIGHT
    BEQ :+
        LDA dd_px
        CMP #(DD_W-1)
        BCS :+
        INC dd_px
    :
    LDA btn_1
    AND #BTN_UP
    BEQ :+
        LDA dd_py
        BEQ :+
        DEC dd_py
    :
    LDA btn_1
    AND #BTN_DOWN
    BEQ :+
        LDA dd_py
        CMP #(DD_H-1)
        BCS :+
        INC dd_py
    :

    @fire:
    LDA btn_1
    AND #(BTN_A+BTN_B)
    BEQ @done
    LDA dd_boss
    BEQ @done
    CMP #6
    BCS @done
    LDA dd_cool
    BNE @done
    LDA dd_sy
    CMP #$FF
    BNE @done
    LDA dd_px
    STA dd_sx
    LDA dd_py
    STA dd_sy
    LDA #4
    STA dd_cool
    @done:
    RTS

;****************
; Main loop
;****************

dodge_main:
    ; seed the generator from the engine seed (never 0)
    LDA seed+0
    STA dd_rng+0
    LDA seed+1
    ORA #$01
    STA dd_rng+1
    LDA #$00
    STA dd_ent
    JSR dd_start_screen

    @frame:
        @wait:
            INC dd_ent
            BIT nmi_flags
            BPL @wait
        LDA #(NMI_SPR+NMI_SCRL+NMI_BKG)
        STA nmi_flags

        JSR readjoy_safe
        LDA btn_1
        AND #BTN_SELECT
        BEQ :+
            JMP @exit
        :
        LDA btn_1
        AND #BTN_START
        BEQ :+
        LDA dd_state
        BEQ :+
            JSR dd_start_screen
            JMP @frame
        :
        LDA dd_state
        BNE :+
            JSR dd_input
        :

        ; game tick every ~80 ms (5,5,5,5,4 frames)
        LDA dd_state
        BNE @phase
        DEC dd_fc
        BNE @phase
        LDX dd_cad
        INX
        CPX #5
        BCC :+
        LDX #0
        :
        STX dd_cad
        LDA #5
        CPX #4
        BNE :+
        LDA #4
        :
        STA dd_fc
        JSR dd_tick
        JSR dd_build_arena
        LDA #1
        STA dd_phase
        JMP @sprites

        ; the screen update is spread over several frames
        @phase:
        LDA dd_phase
        BEQ @sprites
        CMP #1
        BNE @p2
            JSR dd_build_text
            LDA #2
            STA dd_phase
            JMP @sprites
        @p2:
        CMP #2
        BNE @p3
            LDA #0
            LDX #10
            JSR dd_diff_range
            LDA #3
            STA dd_phase
            JMP @sprites
        @p3:
        LDA #11
        LDX #(DD_GRID_ROWS-1)
        JSR dd_diff_range
        LDA #0
        STA dd_phase

        @sprites:
        JSR remove_all_spr
        LDA dd_px
        CLC
        ADC #1
        ASL
        ASL
        ASL
        CLC
        ADC #4
        STA player_x
        LDA dd_py
        CLC
        ADC #6
        ASL
        ASL
        ASL
        CLC
        ADC #4
        STA player_y
        JSR draw_player

        ; MMC5 attribute RAM can only be written while the PPU is rendering
        :
            BIT scanline
            BVC :-
        JSR draw_packet_buffer
        JMP @frame

    @exit:
dd_exit:
    LDA #$00
    STA PPU_MASK
    LDA #NMI_DONE
    STA nmi_flags
    LDA #$02
    STA MMC5_EXT_RAM
    LDA #$00
    TAX
    :
        STA MMC5_EXP_RAM+$000, X
        STA MMC5_EXP_RAM+$100, X
        STA MMC5_EXP_RAM+$200, X
        STA MMC5_EXP_RAM+$300, X
        INX
        BNE :-
    LDA #$01
    STA MMC5_EXT_RAM
    LDA #$00
    STA background_index
    STA background+0
    JSR remove_all_spr
    RTS

;****************
; Landing page
;****************

; Title screen shown once at boot. Returns after START/A is pressed.
landing_main:
    LDA #$00
    STA dd_color
    STA PPU_MASK
    LDA #NMI_DONE
    STA nmi_flags

    ; clear the grid
    LDA #<dd_grid_new
    STA dd_p_new+0
    LDA #>dd_grid_new
    STA dd_p_new+1
    LDX #3
    LDY #0
    LDA #0
    :
        STA (dd_p_new), Y
        INY
        BNE :-
        INC dd_p_new+1
        DEX
        BNE :-

    ; song 2 = "Start Menu"
    LDX #2
    JSR play_music

    DD_AT 17, 14
    DD_STR dd_s_play
    JSR dd_blit_all
    JSR landing_draw_logo

    @frame:
        @wait:
            BIT nmi_flags
            BPL @wait
        LDA #(NMI_SPR+NMI_SCRL+NMI_BKG)
        STA nmi_flags
        JSR readjoy_safe

        JSR remove_all_spr
        LDA #(12*8+4)
        STA player_x
        LDA #(18*8+4)
        STA player_y
        JSR draw_player

        LDA btn_1
        AND #(BTN_START+BTN_A)
        BEQ @frame

    JSR dd_fade_black

    ; stop the title music
    LDA #<.bank(famistudio_music_stop)+$80
    STA MMC5_PRG_BNK0
    JSR famistudio_music_stop
    LDA mmc5_banks+1
    STA MMC5_PRG_BNK0

    ; wait until released so the next menu doesn't see the press
    @release:
        BIT nmi_flags
        BPL @release
        LDA #(NMI_SPR+NMI_SCRL+NMI_BKG)
        STA nmi_flags
        JSR readjoy_safe
        LDA btn_1
        AND #(BTN_START+BTN_A)
        BNE @release

    LDA #$01
    STA landing_done
    JMP dd_exit

; Fade the palettes to black (3 steps of $10), 8 frames per step.
dd_fade_black:
    LDA #3
    STA dd_t
    @fade:
        LDA #8
        STA dd_i
        :
            BIT nmi_flags
            BPL :-
            LDA #(NMI_PLT+NMI_SPR+NMI_SCRL+NMI_BKG)
            STA nmi_flags
            DEC dd_i
            BNE :-
        LDX #24
        :
            LDA palettes, X
            SEC
            SBC #$10
            BCS :+
            LDA #$0F
            :
            STA palettes, X
            DEX
            BPL :--
        DEC dd_t
        BNE @fade
    RTS

; Game over: fade out, show the text for 3 seconds with "Determination",
; then force the landing page to show again. Caller must re-run INIT.
gameover_main:
    JSR dd_fade_black

    JSR remove_all_spr
    LDA #$00
    STA PPU_MASK
    LDA #$00
    STA scroll_x
    STA scroll_y
    LDA #NMI_DONE
    STA nmi_flags

    ; image cells use palette 2 + CHR bank 63, the text cells use the font bank
    LDA #$02
    STA MMC5_EXT_RAM
    LDA #$BF
    LDX #$00
    :
        STA MMC5_EXP_RAM+$000, X
        STA MMC5_EXP_RAM+$100, X
        STA MMC5_EXP_RAM+$200, X
        STA MMC5_EXP_RAM+$300, X
        INX
        BNE :-
    LDX #15
    LDA #DD_ATTR_WHITE
    :
        STA MMC5_EXP_RAM+22*32+8, X
        DEX
        BPL :-
    JSR clear_nt_all_raw

    LDA ppu_ctrl_val
    AND #($FF - PPU_CTRL_INC)
    STA PPU_CTRL
    BIT PPU_STATUS
    LDA #>($2000+GAMEOVER_FIRST_ROW*32)
    STA PPU_ADDR
    LDA #<($2000+GAMEOVER_FIRST_ROW*32)
    STA PPU_ADDR
    LDX #$00
    :
        LDA gameover_nt, X
        STA PPU_DATA
        INX
        BNE :-
    :
        LDA gameover_nt+$100, X
        STA PPU_DATA
        INX
        CPX #<(GAMEOVER_ROWS*32)
        BNE :-

    LDA #>($2000+22*32+8)
    STA PPU_ADDR
    LDA #<($2000+22*32+8)
    STA PPU_ADDR
    LDX #$00
    :
        LDA dd_s_hope, X
        STA PPU_DATA
        INX
        CPX #16
        BNE :-

    LDA #$01
    STA MMC5_EXT_RAM

    JSR init_pal
    LDA #<packet_buffer
    STA packet_buffer_end+0
    LDA #>packet_buffer
    STA packet_buffer_end+1
    LDA #$00
    STA packet_buffer_counter+0
    STA packet_buffer_counter+1
    STA background_index
    STA background+0

    ; song 11 = "Determination"
    LDX #11
    JSR play_music

    LDA #(PPU_MASK_BKG+PPU_MASK_BKG8+PPU_MASK_SPR+PPU_MASK_SPR8)
    STA PPU_MASK
    LDA #(NMI_PLT+NMI_SPR+NMI_SCRL+NMI_BKG)
    STA nmi_flags
    LDA #180
    STA dd_i
    :
        BIT nmi_flags
        BPL :-
        LDA #(NMI_PLT+NMI_SPR+NMI_SCRL+NMI_BKG)
        STA nmi_flags
        DEC dd_i
        BNE :-

    LDA #<.bank(famistudio_music_stop)+$80
    STA MMC5_PRG_BNK0
    JSR famistudio_music_stop
    LDA mmc5_banks+1
    STA MMC5_PRG_BNK0

    LDA #$00
    STA landing_done
    JMP dd_exit

; Draw the SOUL DODGE title image (CHR bank 62, palette 2) over the blank grid.
landing_draw_logo:
    LDA #$00
    STA PPU_MASK
    LDA #NMI_DONE
    STA nmi_flags

    LDA #$02
    STA MMC5_EXT_RAM
    LDA #$BE
    LDX #(LOGO_ROWS*32-1)
    :
        STA MMC5_EXP_RAM+LOGO_FIRST_ROW*32, X
        DEX
        CPX #$FF
        BNE :-

    LDA ppu_ctrl_val
    AND #($FF - PPU_CTRL_INC)
    STA PPU_CTRL
    BIT PPU_STATUS
    LDA #>($2000+LOGO_FIRST_ROW*32)
    STA PPU_ADDR
    LDA #<($2000+LOGO_FIRST_ROW*32)
    STA PPU_ADDR
    LDX #$00
    :
        LDA logo_nt, X
        STA PPU_DATA
        INX
        CPX #(LOGO_ROWS*32)
        BNE :-

    LDA #$01
    STA MMC5_EXT_RAM
    LDA #(PPU_MASK_BKG+PPU_MASK_BKG8+PPU_MASK_SPR+PPU_MASK_SPR8)
    STA PPU_MASK
    LDA #(NMI_PLT+NMI_SPR+NMI_SCRL+NMI_BKG)
    STA nmi_flags
    RTS

; Froggit spared: fade out, show the Froggit picture for 3 seconds with
; "Bird That Carries You Over A Disproportionately Small Gap", then fade to black.
spare_scene_main:
    JSR dd_fade_black
    ; drop every queued sprite (the menu soul)
    LDX #(MAX_SPR-1)
    LDA #$00
    :
        STA spr_buf_anim, X
        DEX
        BPL :-
    LDA #$FF
    STA OAM

    JSR remove_all_spr
    LDA #$00
    STA PPU_MASK
    STA scroll_x
    STA scroll_y
    LDA #NMI_DONE
    STA nmi_flags

    LDA #$02
    STA MMC5_EXT_RAM
    LDA scene_kind
    BNE :+
    LDA #$BD
    BNE :++
:
    LDA #$BC
:
    LDX #$00
    :
        STA MMC5_EXP_RAM+$000, X
        STA MMC5_EXP_RAM+$100, X
        STA MMC5_EXP_RAM+$200, X
        STA MMC5_EXP_RAM+$300, X
        INX
        BNE :-
    JSR clear_nt_all_raw

    LDA ppu_ctrl_val
    AND #($FF - PPU_CTRL_INC)
    STA PPU_CTRL
    BIT PPU_STATUS
    LDA scene_kind
    BNE @kill_nt
    LDA #>($2000+SPARE_FIRST_ROW*32)
    STA PPU_ADDR
    LDA #<($2000+SPARE_FIRST_ROW*32)
    STA PPU_ADDR
    LDA #<spare_nt
    STA tmp+0
    LDA #>spare_nt
    STA tmp+1
    LDA #<(SPARE_ROWS*32)
    STA tmp+2
    JMP @copy_nt
    @kill_nt:
    LDA #>($2000+KILL_FIRST_ROW*32)
    STA PPU_ADDR
    LDA #<($2000+KILL_FIRST_ROW*32)
    STA PPU_ADDR
    LDA #<kill_nt
    STA tmp+0
    LDA #>kill_nt
    STA tmp+1
    LDA #<(KILL_ROWS*32)
    STA tmp+2
    @copy_nt:
    LDY #$00
    :
        LDA (tmp+0), Y
        STA PPU_DATA
        INY
        BNE :-
    INC tmp+1
    LDA tmp+2
    BEQ @copy_done
    :
        LDA (tmp+0), Y
        STA PPU_DATA
        INY
        CPY tmp+2
        BNE :-
    @copy_done:

    LDA #$01
    STA MMC5_EXT_RAM

    JSR init_pal
    LDA #<packet_buffer
    STA packet_buffer_end+0
    LDA #>packet_buffer
    STA packet_buffer_end+1
    LDA #$00
    STA packet_buffer_counter+0
    STA packet_buffer_counter+1
    STA background_index
    STA background+0

    ; song 35 = "Bird That Carries You Over A Disproportionately Small Gap"
    ; song 29 = "Danger Mystery" (kill)
    LDX #35
    LDA scene_kind
    BEQ :+
    LDX #29
:
    JSR play_music

    LDA #(PPU_MASK_BKG+PPU_MASK_BKG8+PPU_MASK_SPR+PPU_MASK_SPR8)
    STA PPU_MASK
    LDA #(NMI_PLT+NMI_SPR+NMI_SCRL+NMI_BKG)
    STA nmi_flags
    LDA #180
    STA dd_i
    :
        BIT nmi_flags
        BPL :-
        LDA #(NMI_PLT+NMI_SPR+NMI_SCRL+NMI_BKG)
        STA nmi_flags
        DEC dd_i
        BNE :-

    JSR dd_fade_black

    LDA #<.bank(famistudio_music_stop)+$80
    STA MMC5_PRG_BNK0
    JSR famistudio_music_stop
    LDA mmc5_banks+1
    STA MMC5_PRG_BNK0

    ; blank screen so the battle exit fade doesn't show the picture again
    LDA #$00
    STA PPU_MASK
    JSR clear_nt_all_raw
    JMP dd_exit

.include "spare_img.inc"
.include "kill_img.inc"

dd_s_hope: .asciiz "Don't lose hope!"
.include "gameover_img.inc"
.include "landing_logo.inc"
dd_s_landing: .asciiz "UNDERTALE BATTLE SIMULATOR"
dd_s_play:  .asciiz "PLAY"

;****************
; Data
;****************

dd_t_move:       .byte 4, 3, 2, 2, 1
dd_t_recovery:  .byte 80, 75, 70, 65, 60
dd_t_attack:    .byte 6, 5, 4, 3, 2
dd_t_wave:      .byte 48, 40, 32, 26, 20
dd_t_obs_spawn: .byte 8, 6, 5, 4, 3
dd_t_obs_wave:  .byte 100, 90, 80, 70, 60
dd_t_fall:      .byte 3, 2, 2, 1, 1
dd_t_health:    .byte 8, 10, 12, 14, 16
dd_t_gap:       .byte 8, 7, 6, 5, 4

dd_art:
    .asciiz "<( o_o )>"
    .asciiz "{( ^_^ )}"
    .asciiz "[( >_< )]"
    .asciiz "<( @_@ )>"
    .asciiz "{( X_X )}"

dd_s_title:   .asciiz "SOUL DODGE - SURVIVE"
dd_s_boss:    .asciiz "BOSS "
dd_s_boss2:   .asciiz "/5 - SHOOT IT!"
dd_s_lv:      .asciiz "LV1 HP "
dd_s_max:     .asciiz "/20 ["
dd_s_hp:      .asciiz "HP "
dd_s_bosshp:  .asciiz "BOSS HP "
dd_s_time:    .asciiz "TIME: "
dd_s_slash:   .asciiz " / "
dd_s_hit:     .asciiz "!! HIT !!"
dd_s_over:    .asciiz "GAME OVER! START = RETRY"
dd_s_win:     .asciiz "YOU WIN! START = RETRY"
dd_s_shoot:   .asciiz "SHOOT THE BOSS! A/B = FIRE"
dd_s_ufo:     .asciiz "SURVIVE! BEWARE THE UFO!"
dd_s_survive: .asciiz "SURVIVE UNTIL THE TIMER ENDS"
dd_s_hint1:   .asciiz "D-PAD MOVE   A/B SHOOT"
dd_s_hint2:   .asciiz "SELECT = BACK TO MENU"
