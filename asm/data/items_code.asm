item_code:
    ; useless item
    item_0:
        .byte item_1 - item_0 - 1
        JMP end_item

    ; testing
    item_1:
        .byte item_2 - item_1 - 1
        LDA item_var
        BNE :+
            INC item_var
            load_dialog_arg TXT_ITEM_1
            JMP read_dialog
        :
        LDA n_dialog
        BEQ :+
            RTS
        :
        JMP end_item

    ; bandage: restore 10 HP
    item_2:
        .byte item_3 - item_2 - 1
        LDA player_stats + PlayerStat::hp
        CLC
        ADC #10
        BCS @max_hp
        CMP player_stats + PlayerStat::maxhp
        BCC @store_hp
        @max_hp:
            LDA player_stats + PlayerStat::maxhp
        @store_hp:
        STA player_stats + PlayerStat::hp
        ora_adr player_flag, #PLAYER_FLAG_DRAW_HP
        JMP end_item

    ; monster candy: restore 10 HP
    item_3:
        .byte item_4 - item_3 - 1
        LDA player_stats + PlayerStat::hp
        CLC
        ADC #10
        BCS @max_hp
        CMP player_stats + PlayerStat::maxhp
        BCC @store_hp
        @max_hp:
            LDA player_stats + PlayerStat::maxhp
        @store_hp:
        STA player_stats + PlayerStat::hp
        ora_adr player_flag, #PLAYER_FLAG_DRAW_HP
        JMP end_item

    ; spider donut: restore 12 HP
    item_4:
        .byte item_5 - item_4 - 1
        LDA player_stats + PlayerStat::hp
        CLC
        ADC #12
        BCS @max_hp
        CMP player_stats + PlayerStat::maxhp
        BCC @store_hp
        @max_hp:
            LDA player_stats + PlayerStat::maxhp
        @store_hp:
        STA player_stats + PlayerStat::hp
        ora_adr player_flag, #PLAYER_FLAG_DRAW_HP
        JMP end_item

    ; cinnamon pie: restore HP to maximum
    item_5:
        .byte item_6 - item_5 - 1
        LDA player_stats + PlayerStat::maxhp
        STA player_stats + PlayerStat::hp
        ora_adr player_flag, #PLAYER_FLAG_DRAW_HP
        JMP end_item

    item_6:
    .repeat 250
        .byte $03
        JMP end_item
    .endrepeat
