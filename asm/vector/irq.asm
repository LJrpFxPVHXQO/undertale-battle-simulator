;***********
; IRQ vector
;***********


IRQ:
    ; save register
    PHA

    ; clear APU interrupt
    LDA APU_STATUS

    BIT MMC5_SCNL_STAT
    BPL :+
        JMP SCANLINE_IRQ
    :

    ; restore register
    PLA
    ; return
    RTI



SCANLINE_IRQ:
    LDA scanline
    BNE :+
        ORA #$40
        STA scanline
        LDA sans_gf
        BEQ @plain
        ; Sans glide: the top of the screen is scrolled by NMI, restore at line 123
        LDA #123
        BNE @setval
        @plain:
        LDA #$70
        @setval:
        STA MMC5_SCNL_VAL
        JMP @end
    :
    AND #$FF - $40
    STA scanline
    LDA sans_gf
    BEQ @end
    ; back to extended attributes for the rest of the screen
    LDA #$01
    STA MMC5_EXT_RAM
    BIT PPU_STATUS
    LDA #$00
    STA PPU_SCROLL
    STA PPU_SCROLL

    @end:
    INC scanline
    ; restore register
    PLA
    ; return
    RTI

