*-----------------------------------------------------------
* Title      : 7 Segment LED
* Written by : Joshua Newell
* Date       : 10/5/18
* Description: Simulate a 7 Segment LED
* 
* Use 7 segments to represent lines in a number
* Display each segment based on whether or not it is included in the array of lines for the specified number
*-----------------------------------------------------------
SEGMENT_LENGTH          EQU     10                                                  ;The length of each segment
SEGMENT_WIDTH           EQU     5                                                   ;The width of each segment
SEGMENT_COLOR           EQU     $00FFFFFF                                           ;The color to draw each segment
DIGIT_PADDING           EQU     5                                                   ;How many pixels to leave between each digit

SCORE_SCREEN_POSY       EQU     (HEADER_HEIGHT-(SEGMENT_LENGTH+SEGMENT_WIDTH)*2)/2  ;Center the display vertically in the header
SCORE_SCREEN_OFFSETX    EQU     SCORE_SCREEN_POSY                                   ;Use the same offset horizontally
SCORE_SCREEN_POSX       EQU     SCREEN_WIDTH-SCORE_SCREEN_OFFSETX+SEGMENT_WIDTH     ;Align right

********************************************************************
*
* Draw a digit on the LED in the correct place
*
* Inval old pixels
* Use an array of masks for each digit to define structure of the display for each number
* And another array for the location of each segment's beginning and ending x and y
*
********************************************************************

DrawLED:
    movem.l         ALL_REG,-(a7)                                   ;Push registers to stack
    
    lea             SegmentMaskArray,a0                             ;Load our array of masks
    clr.l           d5
    move.b          (a0,d0),d5                                      ;Get the mask of our current number
    move.l          d5,d6
    
    lea             SegmentStartXArray,a1                           ;Get coordinate arrays
    lea             SegmentEndXArray,a2
    lea             SegmentStartYArray,a3
    lea             SegmentEndYArray,a4
    
    move.l          #SCORE_SCREEN_POSX,d0                           ;Set location on screen
    move.w          SignificantDigits,d2                            ;Offset to the left based on which digit we are displaying
    sub.w           d7,d2
    mulu            #SEGMENT_LENGTH+SEGMENT_WIDTH+DIGIT_PADDING,d2  ;By the width of each full display + the padding between
    sub.l           d2,d0
    move.l          #SEGMENT_LENGTH+SEGMENT_WIDTH+1,d2              ;Get the full width of the number
    move.l          #SCORE_SCREEN_POSY,d1                           ;Get the Y location
    
    move.l          #SEGMENT_LENGTH*2+SEGMENT_WIDTH*2+1,d3          ;Get the full height of the number
    move.l          d0,d4                                           ;Get screen X,Y location
    move.l          d1,d5
    
    lea             HeaderBackground,a0                             ;Get the address of the background image to inval the old number
    jsr             InitImage                                       ;Draw the background image over the old number
    
    move.l          #SET_PEN_TRAP_CODE,d0                           ;Set the color of the LED segments
    move.l          #SEGMENT_COLOR,d1
    trap            #15    
    move.l          #SET_FILL_TRAP_CODE,d0
    trap            #15
    
    move.l          #SCORE_SCREEN_POSX,d0                           ;Get the X coordinate on screen of the current digit
    move.w          SignificantDigits,d2                            ;Offset to current digit
    sub.w           d7,d2                                           
    mulu            #SEGMENT_LENGTH+SEGMENT_WIDTH+DIGIT_PADDING,d2  ;Multiply by width of number + padding to position properly
    sub.l           d2,d0
    
    move.l          d0,d1                                           ;Initialize the ending X coordinate of the segment
    move.l          d1,d3
    move.l          #SCORE_SCREEN_POSY,d2                           ;Initialize the starting and ending Y coordinates of the segment
    move.l          d2,d4
    
    move.l          #6,d7                                           ;Use 6 for counter for 7 segments
    move.l          d6,d5                                           ;Copy our mask
    move.l          #DRAW_SQUARE_TRAP_CODE,d0
    
DrawSegment:
    move.l          d5,d6                                           ;Get the last bit of our mask
    andi            #$01,d6                                         ;If it is set to display, show it!
    beq             NextBit                                         ;Otherwise, don't
    
    movem.l         d1-d5,-(a7)                                     ;Push current registers to stack
    clr.l           d5
    move.b          (a1,d7),d5                                      ;Get start X
    add.w           d5,d1
    move.b          (a3,d7),d5                                      ;Start Y
    add.w           d5,d2
    move.b          (a2,d7),d5                                      ;End X
    add.w           d5,d3
    move.b          (a4,d7),d5                                      ;End Y
    add.w           d5,d4
    
    trap            #15                                             ;Draw a rectangle for the segment
    movem.l         (a7)+,d1-d5                                     ;Restore the stack
    
NextBit:    
    lsr.l           #1,d5                                           ;Shift the mask for next segment bit
    dbra            d7,DrawSegment                                  ;Loop
    
    movem.l         (a7)+,d0-d7/a0-a6                               ;Restore stack
    rts
    


SegmentMaskArray    dc.b    $7E,$30,$6D,$79,$33,$5B,$5F,$70,$7F,$73     ;Each byte is a bit mask for which segments should be active at a given index

SegmentStartXArray  dc.b    0,SEGMENT_LENGTH,SEGMENT_LENGTH,0,0,0,0     ;Starting X coordinates of each segment

SegmentEndXArray    dc.b    SEGMENT_LENGTH+SEGMENT_WIDTH                ;Ending X coordinates of each segment
                    dc.b    SEGMENT_LENGTH+SEGMENT_WIDTH
                    dc.b    SEGMENT_LENGTH+SEGMENT_WIDTH
                    dc.b    SEGMENT_LENGTH+SEGMENT_WIDTH
                    dc.b    SEGMENT_WIDTH
                    dc.b    SEGMENT_WIDTH
                    dc.b    SEGMENT_LENGTH+SEGMENT_WIDTH

SegmentStartYArray  dc.b    0                                           ;Starting Y coordinates of each segment
                    dc.b    0
                    dc.b    SEGMENT_LENGTH+SEGMENT_WIDTH
                    dc.b    SEGMENT_LENGTH*2+SEGMENT_WIDTH
                    dc.b    SEGMENT_LENGTH+SEGMENT_WIDTH
                    dc.b    0
                    dc.b    SEGMENT_LENGTH
                    
SegmentEndYArray    dc.b    SEGMENT_WIDTH                               ;Ending Y coordinates of each segment
                    dc.b    SEGMENT_LENGTH+SEGMENT_WIDTH
                    dc.b    SEGMENT_LENGTH*2+SEGMENT_WIDTH*2
                    dc.b    SEGMENT_LENGTH*2+SEGMENT_WIDTH*2
                    dc.b    SEGMENT_LENGTH*2+SEGMENT_WIDTH*2
                    dc.b    SEGMENT_LENGTH+SEGMENT_WIDTH
                    dc.b    SEGMENT_LENGTH+SEGMENT_WIDTH



*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
