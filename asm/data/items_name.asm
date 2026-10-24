.segment "ITEM_BNK"

item_names:
    .byte $80, "!IMPOSSIBLE!", $00, $00, $00
    .byte $80, "* USELESS", $00, $00, $00, $00, $00, $00
    .byte $80, "* BANDAGE", $00, $00, $00, $00, $00, $00
    .byte $80, "MONSTER CANDY", $00, $00
    .byte $80, "* SPIDER DONUT", $00
    .byte $80, "* CINNAMON PIE", $00
    .repeat 250
        .byte $80, "* NONAME", $00, $00, $00, $00, $00, $00, $00
    .endrepeat
