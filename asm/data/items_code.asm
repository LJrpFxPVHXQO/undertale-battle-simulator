; A = HP to heal, the result is capped to the max HP
item_heal:
    CLC
    ADC player_stats + PlayerStat::hp
    BCS @max
    CMP player_stats + PlayerStat::maxhp
    BCC @set
    @max:
    LDA player_stats + PlayerStat::maxhp
    @set:
    STA player_stats + PlayerStat::hp
    ora_adr player_flag, #PLAYER_FLAG_DRAW_HP
    RTS

; Items: the heal amount goes in A, $FF = full heal.
.macro HEAL_ITEM cur, nxt, amount, txt
cur:
    .byte nxt - cur - 1
    LDA item_var
    BNE :+
        INC item_var
        LDA #amount
        JSR item_heal
        load_dialog_arg txt
        JMP read_dialog
    :
    LDA n_dialog
    BEQ :+
        RTS
    :
    JMP end_item
.endmacro

item_code:
    ; useless item
    item_0:
        .byte item_1 - item_0 - 1
        JMP end_item

    HEAL_ITEM item_1, item_2, 10, TXT_ITEM_BANDAGE
    HEAL_ITEM item_2, item_3, 10, TXT_ITEM_CANDY
    HEAL_ITEM item_3, item_4, 12, TXT_ITEM_DONUT
    HEAL_ITEM item_4, item_5, $FF, TXT_ITEM_PIE

    item_5:
    .repeat 251
        .byte $03
        JMP end_item
    .endrepeat
