.segment "ITEM_BNK"

item_names:
    .byte $80, "!IMPOSSIBLE!", $00, $00, $00
    .byte $80, "* Bandage", $00, $00, $00, $00, $00, $00
    .byte $80, "* Mon. Candy", $00, $00, $00
    .byte $80, "* Spdr Donut", $00, $00, $00
    .byte $80, "* Cinn. Pie", $00, $00, $00, $00
    .repeat 251
        .byte $80, "* NONAME", $00, $00, $00, $00, $00, $00, $00
    .endrepeat
