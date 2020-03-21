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
        int     0x21                        ;Move file pointer to 0x0A

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
        mov     BX, Colors.DOS_TO_RGB24_STRUCT
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

        .DOS_TO_RGB24_STRUCT    db      0,      0,      0
                                db      0,      0,      170
                                db      0,      170,    0
                                db      0,      170,    170
                                db      170,    0,      0
                                db      170,    0,      170
                                db      170,    85,     0
                                db      170,    170,    170      ;8

                                db      85,     85,     85
                                db      85,     85,     255
                                db      85,     255,    85
                                db      85,     255,    255
                                db      255,    85,     85
                                db      255,    85,     255
                                db      255,    255,    85
                                db      255,    255,    255      ;16

                                db      0,      0,      0
                                db      16,     16,     16
                                db      32,     32,     32
                                db      53,     53,     53
                                db      69,     69,     69
                                db      85,     85,     85
                                db      101,    101,    101
                                db      117,    117,    117      ;24

                                db      138,    138,    138
                                db      154,    154,    154
                                db      170,    170,    170
                                db      186,    186,    186
                                db      202,    202,    202
                                db      223,    223,    223
                                db      239,    239,    239
                                db      255,    255,    255      ;32

                                db      0,      0,      255
                                db      65,     0,      255
                                db      130,    0,      255
                                db      190,    0,      255
                                db      255,    0,      255
                                db      255,    0,      190
                                db      255,    0,      130
                                db      255,    0,      65       ;40

                                db      255,    0,      0
                                db      255,    65,     0
                                db      255,    130,    0
                                db      255,    190,    0
                                db      255,    255,    0
                                db      190,    255,    0
                                db      130,    255,    0
                                db      65,     255,    0        ;48

                                db      0,      255,    0
                                db      0,      255,    65
                                db      0,      255,    130
                                db      0,      255,    190
                                db      0,      255,    255
                                db      0,      190,    255
                                db      0,      130,    255
                                db      0,      65,     255      ;56

                                db      130,    130,    255
                                db      158,    130,    255
                                db      190,    130,    255
                                db      223,    130,    255
                                db      255,    130,    255
                                db      255,    130,    223
                                db      255,    130,    190
                                db      255,    130,    158      ;64

                                db      255,    130,    130
                                db      255,    158,    130
                                db      255,    190,    130
                                db      255,    223,    130
                                db      255,    255,    130
                                db      223,    255,    130
                                db      190,    255,    130
                                db      158,    255,    130      ;72

                                db      130,    255,    130
                                db      130,    255,    158
                                db      130,    255,    190
                                db      130,    255,    223
                                db      130,    255,    255
                                db      130,    223,    255
                                db      130,    190,    255
                                db      130,    158,    255      ;80

                                db      186,    186,    255
                                db      202,    186,    255
                                db      223,    186,    255
                                db      239,    186,    255
                                db      255,    186,    255
                                db      255,    186,    239
                                db      255,    186,    223
                                db      255,    186,    202      ;88

                                db      255,    186,    186
                                db      255,    202,    186
                                db      255,    223,    186
                                db      255,    239,    186
                                db      255,    255,    186
                                db      239,    255,    186
                                db      223,    255,    186
                                db      202,    255,    186      ;96

                                db      186,    255,    186
                                db      186,    255,    202
                                db      186,    255,    223
                                db      186,    255,    239
                                db      186,    255,    255
                                db      186,    239,    255
                                db      186,    223,    255
                                db      186,    202,    255      ;104

                                db      0,      0,      113
                                db      28,     0,      113
                                db      57,     0,      113
                                db      85,     0,      113
                                db      113,    0,      113
                                db      113,    0,      85
                                db      113,    0,      57
                                db      113,    0,      28       ;112

                                db      113,    0,      0
                                db      113,    28,     0
                                db      113,    57,     0
                                db      113,    85,     0
                                db      113,    113,    0
                                db      85,     113,    0
                                db      57,     113,    0
                                db      28,     113,    0        ;120

                                db      0,      113,    0
                                db      0,      113,    28
                                db      0,      113,    57
                                db      0,      113,    85
                                db      0,      113,    113
                                db      0,      85,     113
                                db      0,      57,     113
                                db      0,      28,     113      ;128

                                db      57,     57,     113
                                db      69,     57,     113
                                db      85,     57,     113
                                db      97,     57,     113
                                db      113,    57,     113
                                db      113,    57,     97
                                db      113,    57,     85
                                db      113,    57,     69       ;136

                                db      113,    57,     57
                                db      113,    69,     57
                                db      113,    85,     57
                                db      113,    97,     57
                                db      113,    113,    57
                                db      97,     113,    57
                                db      85,     113,    57
                                db      69,     113,    57       ;144

                                db      57,     113,    57
                                db      57,     113,    69
                                db      57,     113,    85
                                db      57,     113,    97
                                db      57,     113,    113
                                db      57,     97,     113
                                db      57,     85,     113
                                db      57,     69,     113      ;152

                                db      81,     81,     113
                                db      89,     81,     113
                                db      97,     81,     113
                                db      105,    81,     113
                                db      113,    81,     113
                                db      113,    81,     105
                                db      113,    81,     97
                                db      113,    81,     89       ;160

                                db      113,    81,     81
                                db      113,    89,     81
                                db      113,    97,     81
                                db      113,    105,    81
                                db      113,    113,    81
                                db      105,    113,    81
                                db      97,     113,    81
                                db      89,     113,    81       ;168

                                db      81,     113,    81
                                db      81,     113,    89
                                db      81,     113,    97
                                db      81,     113,    105
                                db      81,     113,    113
                                db      81,     105,    113
                                db      81,     97,     113
                                db      81,     89,     113      ;176

                                db      0,      0,      65
                                db      16,     0,      65
                                db      32,     0,      65
                                db      49,     0,      65
                                db      65,     0,      65
                                db      65,     0,      49
                                db      65,     0,      32
                                db      65,     0,      16       ;184

                                db      65,     0,      0
                                db      65,     16,     0
                                db      65,     32,     0
                                db      65,     49,     0
                                db      65,     65,     0
                                db      49,     65,     0
                                db      32,     65,     0
                                db      16,     65,     0        ;192

                                db      0,      65,     0
                                db      0,      65,     16
                                db      0,      65,     32
                                db      0,      65,     49
                                db      0,      65,     65
                                db      0,      49,     65
                                db      0,      32,     65
                                db      0,      16,     65       ;200

                                db      32,     32,     65
                                db      40,     32,     65
                                db      49,     32,     65
                                db      57,     32,     65
                                db      65,     32,     65
                                db      65,     32,     57
                                db      65,     32,     49
                                db      65,     32,     40       ;208

                                db      65,     32,     32
                                db      65,     40,     32
                                db      65,     49,     32
                                db      65,     57,     32
                                db      65,     65,     32
                                db      57,     65,     32
                                db      49,     65,     32
                                db      40,     65,     32       ;216

                                db      32,     65,     32
                                db      32,     65,     40
                                db      32,     65,     49
                                db      32,     65,     57
                                db      32,     65,     65
                                db      32,     57,     65
                                db      32,     49,     65
                                db      32,     40,     65       ;224

                                db      45,     45,     65
                                db      49,     45,     65
                                db      53,     45,     65
                                db      61,     45,     65
                                db      65,     45,     65
                                db      65,     45,     61
                                db      65,     45,     53
                                db      65,     45,     49       ;232

                                db      65,     45,     45
                                db      65,     49,     45
                                db      65,     53,     45
                                db      65,     61,     45
                                db      65,     65,     45
                                db      61,     65,     45
                                db      53,     65,     45
                                db      49,     65,     45       ;240


                                db      45,     65,     45
                                db      45,     65,     49
                                db      45,     65,     61
                                db      45,     65,     65
                                db      45,     61,     65
                                db      45,     53,     65
                                db      45,     49,     65
                                db      45,     49,     65       ;248
















