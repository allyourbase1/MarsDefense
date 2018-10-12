*-----------------------------------------------------------
* Title      : Star Background
* Written by : Joshua Newell
* Date       : 10/3/18
* Description: Create and update a background of stars
* Stars are small circles
* Use 2 arrays, one for smaller stars that move slower
* One for larger stars that move faster, giving a parallax effect
*-----------------------------------------------------------
NUM_SMALL_STARS     EQU 200                             ;Number of small stars to create
NUM_LARGE_STARS     EQU 100                             ;Number of larger stars to create
STAR_COLOR          EQU $00FFFFFF                       ;Color to use for stars
SPACE_COLOR         EQU $00000000                       ;Color to use for space
PARALLAX_AMOUNT     EQU 1                               ;Ratio of parallax scrolling to use
OFFSET_PER_FRAME    EQU 1                               ;Amount to move stars by per frame

STAR_SIZE_SMALL     EQU 1                               ;Radius in pixels of small stars
STAR_SIZE_LARGE     EQU 2                               ;Radius of larger stars

DRAW_CIRCLE_TASK    EQU 88                              ;Trap codes for Sim68K hardware simulation
SET_FILL_TASK       EQU 81
SET_PEN_TASK        EQU 80
GET_RES_TASK        EQU 33
    
********************************************************************
*
* Initialize both star fields
* Use array for X and Y for each field 
*
********************************************************************
    
InitStars:
    move.l          #STAR_COLOR,d1                      ;Set outline and fill colors
    move.l          #SET_PEN_TASK,d0
    trap            #15
    
    move.l          #SET_FILL_TASK,d0
    trap            #15

    move.l          #NUM_SMALL_STARS,d7                 ;Set parameters for loop to initialize small star field
    sub.l           #1,d7                               ;Set loop counter
    lea             StarArraySmallX,a0                  ;Get array addresses
    lea             StarArraySmallY,a1
    clr.l           d1
    move.w          #STAR_SIZE_SMALL,CurrentSize        ;Set current star size to small
    jsr             InitStarsLoop                       ;Initialize small stars
    
    move.l          #NUM_LARGE_STARS,d7                 ;Repeat this step for initialization of large stars
    sub.l           #1,d7
    lea             StarArrayLargeX,a0
    lea             StarArrayLargeY,a1
    clr.l           d1
    move.w          #STAR_SIZE_LARGE,CurrentSize
    jsr             InitStarsLoop
    rts                                                 

InitStarsLoop:
    jsr             GetRandomByteIntoD6                 ;Get a random word by getting two random bytes
    lsl             #8,d6
    move.w          d6,d5
    jsr             GetRandomByteIntoD6
    add.w           d5,d6
    move.w          #SCREEN_WIDTH,d0                    ;Mod with Screen width to get random X coordinate
    divu            d0,d6
    swap            d6                                  
    
    move.w          d6,d1                               ;Save the X coordinate
    move.w          d1,(a0)+
    move.l          d1,d3
    add.w           CurrentSize,d3                      ;Add the width to get the X coordinates for drawing
    
    jsr             GetRandomByteIntoD6                 ;Get a random for Y coordinate
    lsl             #8,d6
    move.w          d6,d5
    jsr             GetRandomByteIntoD6
    add.w           d5,d6
    move.w          #SCREEN_HEIGHT,d0                   ;Get the screen height
    sub.w           #GROUND_HEIGHT,d0                   ;Adjust to fit in field of play
    sub.w           #HEADER_HEIGHT,d0
    sub.w           CurrentSize,d0
    sub.w           CurrentSize,d0
    divu            d0,d6                               ;Mod with size to get random Y coordinate
    swap            d6
    
    move.w          d6,d2                               ;Store for drawing
    add.w           #HEADER_HEIGHT,d2                   ;Offset to keep within field of play
    add.w           CurrentSize,d2
    move.w          d2,(a1)+                            ;Save the Y coordinate
    move.l          d2,d4
    add.w           CurrentSize,d4                      ;Add star height to get Y coordinates for drawing
    
    move.l          #DRAW_CIRCLE_TASK,d0                ;Draw the star!
    trap            #15
    
    dbra            d7,InitStarsLoop                    ;Loop until all stars have been created
    rts
    
********************************************************************
*
* Move the stars by appropriate speed for parallax scrolling
* Clear out old stars, draw in new position
*
********************************************************************
    
UpdateStars:
    movem.l         ALL_REG,-(a7)                       ;Push registers to stack
    move.w          #OFFSET_PER_FRAME,BackgroundOffset  ;Set speed to move stars
    jsr             UpdateSmallStars                    ;Move and draw small stars
    jsr             UpdateLargeStars                    ;Move and draw large stars
    move.w          #0,BackgroundOffset                 ;Reset speed
    movem.l         (a7)+,ALL_REG                       ;Restore stack
    rts
    
UpdateSmallStars:
    move.l          #NUM_SMALL_STARS,d7                 ;Set index for loop
    sub.l           #1,d7
    lea             StarArraySmallX,a0                  ;Get X,Y coordinates
    lea             StarArraySmallY,a1
    move.w          #STAR_SIZE_SMALL,CurrentSize        ;Set size for Inval and drawing
    
    clr.l           d1
    clr.l           d2
    
    jsr             UpdateStarLoop                      ;Update the stars
    rts
    
UpdateLargeStars:
    move.l          #NUM_LARGE_STARS,d7                 ;Set index for loop
    sub.l           #1,d7
    lea             StarArrayLargeX,a0                  ;Get X,Y coordinates
    lea             StarArrayLargeY,a1
    move.w          #STAR_SIZE_LARGE,CurrentSize        ;Set size for Inval and drawing
    move.w          BackgroundOffset,d0                 ;Set speed
    lsl             #PARALLAX_AMOUNT,d0
    move.w          d0,BackgroundOffset                 ;Save the current speed
    
    clr.l           d1
    clr.l           d2
    
    jsr             UpdateStarLoop                      ;Do the update
    rts
   
********************************************************************
*
* This is where the stars are actually Inval'd and drawn
*
********************************************************************
    
UpdateStarLoop:
    move.l          #SPACE_COLOR,d1                     ;Set pen and fill to black for space
    move.l          #SET_PEN_TASK,d0
    trap            #15
    move.l          #SET_FILL_TASK,d0
    trap            #15
    
    move.w          (a0),d1                             ;Get the starting X coordinate
    move.l          d1,d3
    add.w           CurrentSize,d3                      ;Get ending X
        
    move.w          (a1),d2                             ;Get starting Y
    move.l          d2,d4
    add.w           CurrentSize,d4                      ;Get ending Y
    
    move.l          #DRAW_CIRCLE_TASK,d0                ;Inval the old star position
    trap            #15
    
    move.w          BackgroundOffset,d0                 ;Update the X position of this star with the speed
    sub.w           d0,(a0)
    bgt             DrawStar                            ;Draw it in its new location
    
    move.w          #SCREEN_WIDTH,(a0)                  ;If the star moved all the way left of the screen, move it to the right side
    
DrawStar:
    move.l          #STAR_COLOR,d1                      ;Set pen and fill color to white for stars
    move.l          #SET_PEN_TASK,d0
    trap            #15
    move.l          #SET_FILL_TASK,d0
    trap            #15
    
    move.w          (a0)+,d1                            ;Get the starting X and move to next X
    move.l          d1,d3
    add.w           CurrentSize,d3                      ;Get ending X
    move.w          (a1)+,d2                            ;Get starting Y and move to next Y
    move.l          d2,d4
    add.w           CurrentSize,d4                      ;Get ending Y
    
    move.l          #DRAW_CIRCLE_TASK,d0                ;Draw the star
    trap            #15

    dbra            d7,UpdateStarLoop                   ;Loop to next star
    rts



StarArraySmallX     ds.w    NUM_SMALL_STARS             ;X coordinates of all small stars
StarArraySmallY     ds.w    NUM_SMALL_STARS             ;Y coordinates of small stars
StarArrayLargeX     ds.w    NUM_LARGE_STARS             ;Xs of large stars
StarArrayLargeY     ds.w    NUM_LARGE_STARS             ;Ys of large stars
CurrentSize         dc.w    0                           ;Size used for calculations in display

BackgroundOffset    dc.w    0                           ;Speed of background for movement



*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
