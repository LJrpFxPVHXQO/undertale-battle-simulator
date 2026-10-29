dmg_anim:
    JSR sans_glide_update

    ; if fight_timer == 0
    LDA fight_timer
        ; goto init
        BEQ @init
    ; elif fight_timer < FIGHT_STRICK_TIME
    CMP #FIGHT_STRICK_TIME
        ; goto strick_anim
        blt @strick_anim
    ; elif fight_timer < FIGHT_NUMBER_TIME + FIGHT_STRICK_TIME
    CMP #FIGHT_NUMBER_TIME + FIGHT_STRICK_TIME
        ; goto number_anim
        blt @number_anim
    ; else
        ; goto end_anim

    @end_anim:
        ; clear_main_box()
        JSR clear_main_box
        ; subtract the completed strike from the selected monster's HP
        LDA selected_monster
        shift ASL, MONSTER_STAT_SHIFT
        TAX
        LDA monster_stats + MonsterStat::hp, X
        SEC
        SBC fight_damage
        STA monster_stats + MonsterStat::hp, X
        LDA monster_stats + MonsterStat::hp + 1, X
        SBC #$00
        STA monster_stats + MonsterStat::hp + 1, X
        JSR sans_kill_check
        BCC @defeated
        ; call monster hit event
        mvx cur_monster_fight_pos, selected_monster
        LDA #EVENT::HIT
        STA monster_events, X
        ; fight_state--
        DEC fight_state
        ; fight_timer = 0
        mov fight_timer, #0
        ; switch to wait soul
        mov player_soul, #SOUL::WAIT
        JSR switch_player_soul
        ; set CHR bank 0 to player sprites
        mov MMC5_CHR_BNK0, #PLAYER_SPRITE_BNK
        ; return
        RTS

    @defeated:
        LDA #$00
        STA monster_stats + MonsterStat::hp, X
        STA monster_stats + MonsterStat::hp + 1, X
        JSR kill_reward
        JMP begin_battle_victory


    @init:
        ; display strick anim (also played on a miss)
        mov cur_monster_fight_pos, selected_monster
        LDA #<ANIM_DATA_MONSTERS_STRIKE_STRIKE_1
        STA tmp+0
        LDA #>ANIM_DATA_MONSTERS_STRIKE_STRIKE_1
        STA tmp+1
        JSR add_anim
        ; dmg -> BCD
        mov tmp+0, fight_damage
        mov tmp+1, #0
        JSR int16_2_bcd
        mov fight_bcd+0, tmp+2
        mov fight_bcd+1, tmp+3
        mov fight_bcd+2, tmp+4
        ;
        JMP @end

    @strick_anim:
        JSR draw_hitmark
        JMP @end

    @number_anim:
        ; set CHR bank 0 to dmg sprites
        mov MMC5_CHR_BNK0, #DMG_SPRITE_BNK
        JSR dmg_hpbar_update
        ; xy pos
        JSR monster_fightid_to_pos
        TXA
        sub #$08
        STA tmp+1
        STY tmp+2
        ;
        LDA fight_damage
        BEQ @miss
            ; 10000
            LDA fight_bcd+2
            AND #$0F
            BEQ :+ ; skip if == 0
                STA tmp
                JSR draw_digit
            :
            ; 1000
            LDA fight_bcd+1
            shift LSR, 4
            BEQ :+ ; skip if == 0
                STA tmp
                JSR draw_digit
            :
            ; 100
            LDA fight_bcd+1
            AND #$0F
            BEQ :+ ; skip if == 0
                STA tmp
                JSR draw_digit
            :
            ; 10
            LDA fight_bcd+0
            shift LSR, 4
            BEQ :+ ; skip if == 0
                STA tmp
                JSR draw_digit
            :
            ; 1
            LDA fight_bcd+0
            AND #$0F
            STA tmp
            JSR draw_digit
            ;
            JMP @end
        @miss:
            ; 1
            mov tmp, #$0A
            JSR draw_digit
            ;
            JMP @end

    @end:
    ; fight_timer++
    INC fight_timer
    ; return
    RTS


; tmp = digit
; tmp+1 = x pos
; tmp+2 = y pos
draw_digit:
    @param_x = tmp+1
    @param_y = tmp+2
    pushregs

    ; X = digit
    LDX tmp
    ; Y = number of sprite ((table_dmg_sprite[X+1] - table_dmg_sprite[X]) / 2)
    LDA table_dmg_sprite+1, X
    sub table_dmg_sprite, X
    LSR
    TAY
    ; X = offset in dmg_sprites
    LDA table_dmg_sprite, X
    TAX

    ; for each sprite
    @loop:
        phy
        ; get sprite pos in oam
        LDA oam_size
        ASL
        ASL
        TAY
        ; y
        LDA @param_y
        STA OAM+0, Y
        ; tile
        LDA dmg_sprites, X
        STA OAM+1, Y
        INX
        ; atr
        LDA dmg_sprites, X
        STA OAM+2, Y
        INX
        ; x
        LDA @param_x
        STA OAM+3, Y
        ; param_x += 8
        add #$08
        STA @param_x

        ; oam_size++
        INC oam_size
        ;
        ply
    to_y_dec @loop, #0

    ; return
    pullregs
    RTS


; Sans slides out of the way (smooth 3 px steps) before the strike lands
sans_glide_update:
    LDA fight_id
    CMP #$04
    BNE @ret
    ; keep the strike out of the CHR slot Sans' body shares
    LDA #$01
    STA sans_strk
    LDA fight_damage
    BNE @off
    LDA fight_timer
    CMP #12
    BCC @up
    CMP #40
    BCC @hold
    CMP #52
    BCC @down
    @off:
    LDA #$00
    STA sans_glide
    @ret:
    RTS
    @up:
    STA tmp
    ASL
    ADC tmp
    JMP @set
    @hold:
    LDA #36
    JMP @set
    @down:
    STA tmp
    LDA #52
    SEC
    SBC tmp
    STA tmp
    ASL
    ADC tmp
    @set:
    STA sans_gx
    LDA #$01
    STA sans_glide
    RTS

; Sans dies from the first real hit: clears carry (defeated) for fight 4 with damage
sans_kill_check:
    PHP
    LDA fight_id
    CMP #$04
    BNE @keep
    LDA fight_damage
    BEQ @keep
    PLP
    CLC
    RTS
    @keep:
    PLP
    RTS
