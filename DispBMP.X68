*-----------------------------------------------------------
* Title      : Display bmp
* Written by : Joshua Newell
* Date       : 9/19/2018
* Description: Load a bitmip into memory and display it by looping through its internal pixel array
* NOTE       : Currently only supports 24-bit color depth
*-----------------------------------------------------------
ALL_REGISTERS       REG d0-d7/a0-a6

CORNER_X            EQU 260         ;Parameters for display bounds
CORNER_Y            EQU 250
CHUNK_WIDTH         EQU 16
CHUNK_HEIGHT        EQU 16
SCREEN_X            EQU 50
SCREEN_Y            EQU 50

START_PIXELS_OFFSET EQU 10          ;Constant offsets within bitmap file format to get information
WIDTH_OFFSET        EQU 18
HEIGHT_OFFSET       EQU 22
DEPTH_OFFSET        EQU 28

ONE_BYTE            EQU 8           ;Used for bit shift calculations

CORNER_X_OFFSET     EQU 14          ;Stack parameters
CORNER_Y_OFFSET     EQU 12
CHUNK_WIDTH_OFFSET  EQU 10
CHUNK_HEIGHT_OFFSET EQU 8
SCREEN_X_OFFSET     EQU 6
SCREEN_Y_OFFSET     EQU 4

BITMAP_SIGNATURE    EQU 'BM'        ;Information to check if input file is currently supported
SUPPORTED_DEPTH     EQU 24

TASK_PEN_COLOR      EQU 80          ;SimI/O TRAP codes
TASK_DRAW_PIXEL     EQU 82
TASK_SET_RES        EQU 33
   
InitImage:
    movem.l ALL_REGISTERS,-(a7)
    cmp     #BITMAP_SIGNATURE,(a0)              ;Check if using a bitmap file by signature
    bne     FINISH                              ;If not, exit
        
    cmp.b   #SUPPORTED_DEPTH,DEPTH_OFFSET(a0)   ;Check that color depth is supported
    bne     FINISH                              ;If not, exit
    
    move.w  d0,-(a7)                            ;Top left corner X
    move.w  d1,-(a7)                            ;Top left corner Y
    
    move.w  d2,-(a7)                            ;Chunk width
    move.w  d3,-(a7)                            ;Chunk height
    
    move.w  d4,-(a7)                            ;Screen position to draw X
    move.w  d5,-(a7)                            ;Screen position to draw Y

    jsr     DrawImage
    
    add.l   #12,a7                              ;Unroll stack
    
FINISH:    
    movem.l (a7)+,ALL_REGISTERS
    rts

DrawImage:
    move.l  START_PIXELS_OFFSET(a0),d0          ;Get beginning of pixel array in the file
    jsr     ByteSwap
    move.l  d0,StartPixels
    
    move.l  WIDTH_OFFSET(a0),d0                 ;Get the width of the image
    jsr     ByteSwap
    move.l  d0,ImgWidth
    
    ;Bitmap format ensures row size is divisible by 4, if not it adds padding bits to the end of the row
    ;Must account for these in loops, this will get the amount of padding per row so we can account for it
    move.l  d0,d1
    mulu    #3,d1
    and     #3,d1
    move.l  #4,d0
    sub.l   d1,d0
    and     #3,d0
    move.w  d0,RowPadding
    lea     RowPadding,a3
    
    move.l  DEPTH_OFFSET(a0),d0                 ;Get the color depth from the file
    jsr     ByteSwap
    lsr     #3,d0                               ;Divide by 8 to convert from bit depth to bytes, shift right 3 bits
    move.w  d0,BytesPerPixel
    
    move.l  HEIGHT_OFFSET(a0),d0                ;Get the height of the image
    jsr     ByteSwap
    move.l  d0,ImgHeight
    
    add.l   StartPixels,a0                      ;Set the location of the pixel array as our index

    lea     ImgHeight,a1                        ;Get image width and height from memory and store references
    lea     ImgWidth,a2

    move.l  (a2),d0                             ;Add row width in pixels to padding
    sub.w   CHUNK_WIDTH_OFFSET(a7),d0           ;Subtract chunk width in pixels from this sum
    mulu    BytesPerPixel,d0                    ;Multiply by bytes per pixel
    add.w   (a3),d0                             ;In bitmap pixel arrays there is padding to make each row divisible by 4, add to the index to skip
    move.w  d0,RowPaddingByteOffset
    
    move.w  CORNER_X_OFFSET(a7),d0              ;Set inital x position in pixel array
    mulu    BytesPerPixel,d0
    add.l   d0,a0
    
    move.l  (a1),d0                             ;Set initial y position in pixel array
    sub.w   CORNER_Y_OFFSET(a7),d0              ;Get image height - starting y - chunk height
    sub.w   CHUNK_HEIGHT_OFFSET(a7),d0
    move.l  (a2),d1                             ;Multiply by total number of bytes per row to move down correct number of rows
    mulu    BytesPerPixel,d1                    ;Multiply the number of pixels by color depth to get number of bytes per row
    add.w   (a3),d1                             ;Add padding bytes here
    mulu    d1,d0
    add.l   d0,a0                               ;Add BytesPerRow * Starting Y to get to starting pixel index
    
    sub.w   #1,CHUNK_WIDTH_OFFSET(a7)           ;Comparisons are made with 0 so subtract 1 from indices
    sub.w   #1,CHUNK_HEIGHT_OFFSET(a7)
    move.w  CHUNK_WIDTH_OFFSET(a7),d6           ;Set indices for loops for rows and columns
    move.w  CHUNK_HEIGHT_OFFSET(a7),d7
    
    move.w  CHUNK_WIDTH_OFFSET(a7),d3           ;Move data from stack to registers for faster calculations
    move.w  SCREEN_X_OFFSET(a7),d4
    move.w  SCREEN_Y_OFFSET(a7),d5

RowLoop:
    clr.w   d1                                  ;Clear lower word of d0, this is faster than clearing the long and equally safe
    move.b  (a0)+,d1                            ;Get first byte of color (BLUE)
    swap    d1                                  ;Swap the words to get the BLUE value in the correct byte position for Easy68k
    move.b  (a0)+,d1                            ;Get the second byte of color (GREEN)
    lsl     #ONE_BYTE,d1                        ;Shift 1 byte to get the GREEN value in the correct position
    move.b  (a0)+,d1                            ;Get the third byte of color (RED)
    
    cmp.l   #$00FF00FF,d1
    beq     MovePixel
    
;TODO 32 bit color: XOR with alpha bits, if 00, skip pixel
    move.l  #TASK_PEN_COLOR,d0                  ;Set the pen color to the loaded pixel color
    TRAP    #15
    
    move.w  d3,d1                               ;Get the current element of the row
    sub.w   d6,d1
    add.w   d4,d1                               ;Adjust to the indicated screen position X
    
    move.l  d7,d2                               ;Get the current row
    add.w   d5,d2                               ;Adjust to the indicated screen position Y
    
    move.l  #TASK_DRAW_PIXEL,d0                 ;Draw the pixel at the correct position
    TRAP    #15
    
MovePixel:    
    dbra    d6,RowLoop                          ;If not at the end of the current row, loop again
    
    add.w   RowPaddingByteOffset,a0             ;Adjust index to beginning of next row of chunk
    move.w  d3,d6                               ;Reset the x index to the width-1
    dbra    d7,RowLoop

    rts

;Switch Endianness of d0
;Consider the register as 4 bytes, a,b,c,d
;Reorder contents to d,c,b,a
ByteSwap:
    ror     #ONE_BYTE,d0
    swap    d0
    ror     #ONE_BYTE,d0
    
    rts
    
StartPixels             ds.l    1
ImgWidth                ds.l    1
ImgHeight               ds.l    1
RowPadding              ds.w    1
RowPaddingByteOffset    ds.w    1
BytesPerPixel           ds.w    1







*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
