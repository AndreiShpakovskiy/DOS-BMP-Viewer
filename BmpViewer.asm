        org     0x0100

EntryPoint:
        mov     AH, 0x0A
        mov     DX, FileParams.Path
        int     0x21                 ;Get file path

        mov     BX, FileParams.Path
FindEnd:
        inc     BX
        cmp     byte[BX], 0x0D
        jne     FindEnd
        mov     byte[BX], 0          ;Replace 0x0D with 0x00 as line terminator

        call    GetBmpParams         ;Get BMP parameters (saved in "File Params.~" fields
        call    GetSkipbytes         ;Count bytes needed to skip while printing row

SetVideoMode:
        mov     AX, 0x13
        int     0x10                 ;Change videomode to 0x13

PrepareLayout:
        push    0x0A000              ;Put video segment number in ES register
        pop     ES

        call    PrintImage           ;Call this procedure to print image (all parameters are global)

ExitProcess:
        mov     BX, [FileParams.Handle]
        mov     AH, 0x3E
        int     0x21                 ;Close file

        mov     AH, 0x08
        int     0x21
        ret

GetSkipbytes:
        mov     AX, [BmpParams.Width]
        and     AX, 11b
        mov     [BmpParams.SkipBytes], AX   ;So it's just Width % 4
        ret

GetBmpParams:
.OpenFile:
        mov     AX, 0x3D00
        mov     DX, FileParams.Path + 2
        int     0x21                        ;Open file
        mov     [FileParams.Handle], AX     ;Save its handle

.GetOffset:
        mov     AH, 0x42
        mov     AL, 0
        mov     BX, [FileParams.Handle]
        mov     CX, 0
        mov     DX, 0x0A
        int     0x21                        ; Move file pointer to 0x0A

        mov     BX, [FileParams.Handle]
        mov     AH, 0x3F
        mov     DX, BmpParams.Offset
        mov     CX, 2
        int     0x21                        ;Get an offset

.GetWitdh:
        mov     AH, 0x42
        mov     AL, 0
        mov     BX, [FileParams.Handle]
        mov     CX, 0
        mov     DX, 0x12
        int     0x21                        ;Move file pointer to 0x12

        mov     BX, [FileParams.Handle]
        mov     AH, 0x3F
        mov     DX, BmpParams.Width
        mov     CX, 2
        int     0x21                        ;Get image width

.GetHeight:
        mov     AH, 0x42
        mov     AL, 0
        mov     BX, [FileParams.Handle]
        mov     CX, 0
        mov     DX, 0x16
        int     0x21                        ;Move file pointer to 0x16

        mov     BX, [FileParams.Handle]
        mov     AH, 0x3F
        mov     DX, BmpParams.Height
        mov     CX, 2
        int     0x21                        ;Get image height
        ret

GetClosestColor:
        mov     CX, 248                     ;The number of colors available
        mov     BX, DOS_TO_RGB24_STRUCT
        mov     [Colors.MinColorsDistance], 0xFFFF
        xor     DL, DL                      ;DL will hold current analysing color number

;Everything you can see below is nothing but counting distance between tho points in 3D space.
;Coordinates of the first point are given in input file (R,G,B).
;Coordinates of the second one is (R,G,B) representation of DOS-Color with number held in DL.
;DOS-Color number of the closest point to the current given is a color number of current pixel.
;So... just follow this idea. Everything is pretty simple.

.FindColorMatch:
        mov     [Colors.CurColorsDistance], 0

.Red:
        mov     AL, [Colors.RgbBuffer + 2]
        mov     AH, [BX]
        inc     BX
        cmp     AL, AH
        ja      @F
        xchg    AH, AL
@@:
        sub     AL, AH
        shr     AL, 1
        mul     AL
        add     [Colors.CurColorsDistance], AX

.Green:
        mov     AL, [Colors.RgbBuffer + 1]
        mov     AH, [BX]
        inc     BX
        cmp     AL, AH
        ja      @F
        xchg    AH, AL
@@:
        sub     AL, AH
        shr     AL, 1
        mul     AL
        add     [Colors.CurColorsDistance], AX

.Blue:
        mov     AL, [Colors.RgbBuffer]
        mov     AH, [BX]
        inc     BX
        cmp     AL, AH
        ja      @F
        xchg    AH, AL
@@:
        sub     AL, AH
        shr     AL, 1
        mul     AL
        add     [Colors.CurColorsDistance], AX

        mov     AX, [Colors.CurColorsDistance]
        cmp     AX, [Colors.MinColorsDistance]
        ja      @F

.UpdateColorInfo:
        mov     [Colors.MinColorsDistance], AX
        mov     [Colors.ClosestColor], DL

@@:
        inc     DL
        loop    .FindColorMatch
        ret

PrintImage:
        mov     CX, [BmpParams.Height]
        mov     AX, CX
        mov     BX, 20
        mul     BX
        mov     BX, ES
        add     BX, AX
        sub     BX, 20
        mov     ES, BX ;Yeap, we are going to print it from bottom to top

.Print:
        push    CX
        mov     CX, [BmpParams.Width]
        xor     DI, DI

.PrintRow:
.GetPixelInfo:
        push    CX
        mov     AH, 0x42
        mov     AL, 0
        mov     BX, [FileParams.Handle]
        mov     CX, word[BmpParams.Offset + 2]
        mov     DX, word[BmpParams.Offset]
        int     0x21                            ;Don't judge me, please :|

        add     [BmpParams.Offset], 3

        mov     BX, [FileParams.Handle]
        mov     AH, 0x3F
        mov     DX, Colors.RgbBuffer
        mov     CX, 3
        int     0x21

        push    CX
        call    GetClosestColor
        pop     CX

        mov     BL, [Colors.ClosestColor]
        mov     [ES:DI], BL                     ;Using stosb seems like better idea
        inc     DI
        pop     CX
        loop    .PrintRow

        cmp     DI, [BmpParams.Width]
        jnz     @F
        mov     AX, [BmpParams.SkipBytes]
        add     word[BmpParams.Offset], AX
@@:
        pop     CX
        mov     AX, ES
        sub     AX, 20   ;Just a little trick to not to care about actual length of image
        mov     ES, AX
        loop    .Print
        ret

FileParams:
        .Path           db      50, 0, 50 dup (0)
        .Handle         dw      ?

BmpParams:
        .Height         dw      ?
        .Width          dw      ?
        .Offset         dd      ?
        .SkipBytes      dw      ?

Colors:
        .ClosestColor           db      ?
        .MinColorsDistance      dw      ?
        .CurColorsDistance      dw      ?
        .RgbBuffer              db      3 dup (?)

        include 'ColorMapper.asm'