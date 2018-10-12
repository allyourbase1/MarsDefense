*-----------------------------------------------------------
* Title      : Main
* Written by : Joshua Newell
* Date       : 9/28/18
* Description: The main game loops for Mars Defender!
*
* WASD to move your ship, Space to fire
* You control one of the fastest ships in the galaxy!
* It's not as easy as it sounds, however; move with precision to survive the onslaught of enemies!
*-----------------------------------------------------------
ALL_REG                     REG d0-d7/a0-a6

FRAC_BITS                   EQU 4                       ;Use 4 fractional bits for fixed point math
FRAMERATE_TIMER             EQU (100/30)<<FRAC_BITS     ;Denominator is FPS

SCREEN_WIDTH                EQU 640                     ;The dimensions of the game window
SCREEN_HEIGHT               EQU 480

GROUND_COLOR                EQU $002646C6               ;Reddish-brown for ground color
GROUND_HEIGHT               EQU 64                      ;Ground height for printing and limiting play area
SPACE_COLOR                 EQU $00000000               ;Space is black!

HEADER_HEIGHT               EQU 64                      ;Dimensions and colors for in-game header
HEADER_BORDER_WIDTH         EQU 2                       ;Border between play field and UI area
HEADER_BORDER_COLOR         EQU $00FFFFFF

HIGH_SCORE_HEADER_OFFSET    EQU 50                      ;Position on screen of Score
TITLE_OFFSET                EQU 100                     ;Position on screen of Title image

GET_TIME_TRAP_CODE          EQU 8                       ;Sim68K Trap Codes for hardware simulation
DRAWING_MODE_TRAP_CODE      EQU 92
DRAWING_MODE_DOUBLE_BUFFER  EQU 17
REPAINT_SCREEN_TRAP_CODE    EQU 94
SET_RESOLUTION_TRAP_CODE    EQU 33
DRAW_SQUARE_TRAP_CODE       EQU 87
SET_PEN_TRAP_CODE           EQU 80
SET_FILL_TRAP_CODE          EQU 81

    ORG    $1000
********************************************************************
*
* Beginning of game
*
********************************************************************

START:                      
    jsr     SeedRandomNumber                    ;Seed our random number generator right away
    jsr     SetDrawMode                         ;Set double buffering
    
********************************************************************
*
* The loop of the title screen
* Draw the Title screen and wait for input to start the game
*
********************************************************************

TitleLoop:
    jsr     DrawBackground                      ;Draw the background first
    jsr     DrawTitle                           ;Then the Title image
    
    jsr     AwaitInput                          ;Wait for user input to start the game
    
    clr.l   d1                                  ;Clear the screen once user has started the game 
    clr.l   d2                                  ;Clear from 0,0
    move.l  #SCREEN_WIDTH,d3                    ;To edges of screen
    move.l  #SCREEN_HEIGHT,d4
    
    jsr     InvalArea                           ;Clear the screen
    
********************************************************************
*
* Initial setup before starting the game
*
********************************************************************

BeginGame:
    jsr     InitStars                           ;Create the starfield background and display it
    jsr     DrawGround                          ;Draw the ground before the playfield
    jsr     DrawHeader                          ;Draw the header and UI
    
    jsr     SpawnEnemy                          ;Start the game with one enemy in play

********************************************************************
*
* The main game loop!
*
* The logic of the game itself is here
* Update graphics, physics, check for collisions, and update objects and game state accordingly
*
********************************************************************

Main:
    jsr     GetTime                             ;Get the time at the start of each frame to control framerate
    move.l  d1,FrameTimer                       ;Store it for use at the end of the frame
    
    jsr     UpdateStars                         ;Update the position of each star and display them
    jsr     AddSurvivalScore                    ;Check if the player has survived long enough to add another survival point
    
    jsr     GetInput                            ;Get player input
    jsr     MovePlayer                          ;Update player position based on input
    
    jsr     CheckEnemySpawn                     ;See if we are going to spawn another enemy
    jsr     CheckEnemySpeedUp                   ;Check if it's time to speed up the enemies
    jsr     MoveEnemies                         ;Move all the enemies!
    
    jsr     UpdateBullets                       ;Move all the bullets!
    
    jsr     DoFrameTimer                        ;Check if it's time to update the frame
    
    jsr     PaintScreen                         ;If so, repaint the screen
    
    cmp.b   #0,IsPlaying                        ;Are we still alive?
    bgt     Main                                ;Keep playing!
    
********************************************************************
*
* We died! Game over here
*
* Clear the screen, show the high score table, reset all variables and play again!
*
********************************************************************

GameOver:    
    move.l  #0,d1                               ;From 0, 0
    move.l  #0,d2
    move.w  #SCREEN_WIDTH,d3                    ;To the end of screen
    move.w  #SCREEN_HEIGHT,d4   
    jsr     InvalArea                           ;Clear everything
    
    jsr     DrawBackground                      ;Draw the background for the game over screen
    jsr     DrawHighScoreHeader                 ;Draw the high score header
    jsr     DisplayScores                       ;Show the high score table
    
    jsr     InvalArea                           ;Clear the screen
    
    jsr     ResetGameParamters                  ;Reset all gameplay parameters and variables
    
    move.b  #1,IsPlaying                        ;Set game state
    bra     BeginGame                           ;Start playing!

********************************************************************
*
* End of game, should never reach this in normal play
*
********************************************************************

END:
    SIMHALT                                     ; halt simulator
    
    
    
********************************************************************
*
* Set Sim68K to use double buffering
*
********************************************************************

SetDrawMode:
    move.l  #DRAWING_MODE_TRAP_CODE,d0
    move.l  #DRAWING_MODE_DOUBLE_BUFFER,d1
    trap    #15
    
********************************************************************
*
* Get the current time in hundredths of a second since midnight
*
********************************************************************

GetTime:
    move.l  #GET_TIME_TRAP_CODE,d0
    trap    #15
    rts
    
********************************************************************
*
* Check if enough time has passed for our framerate cap
*
********************************************************************

DoFrameTimer:
    movem.l ALL_REG,-(a7)                           ;Push registers to the stack
    move.l  FrameTimer,d2                           ;Get the time since the beginning of the frame
    lsl.l   #FRAC_BITS,d2                           ;Shift it for fixed point math for precision
    
FrameTimerInner:
    jsr     GetTime                                 ;Get the current time
    lsl.l   #FRAC_BITS,d1                           ;Shift for precision
    sub.l   d2,d1                                   ;Subtract the time at the beginning of the frame
    cmp.l   #FRAMERATE_TIMER,d1                     ;Compare this difference to our timer
    blt     FrameTimerInner                         ;If it was too fast, try again
    
    movem.l (a7)+,ALL_REG                           ;Restore stack
    rts                                     
    
********************************************************************
*
* Draw the background image on the entire screen
*
********************************************************************

DrawBackground:
    movem.l ALL_REG,-(a7)                           ;Push all registers to the stack
    lea     Background,a0                           ;Get the address of the background image
        
    clr.l   d0                                      ;Set the parameters for the bitmap display function
    clr.l   d1                                      ;Start at 0,0 in the image
    clr.l   d2
    clr.l   d3
    move.w  #SCREEN_WIDTH,d2                        ;Use screen size as width and height of portion of image to draw
    move.w  #SCREEN_HEIGHT,d3
    clr.l   d4                                      ;Draw at 0,0 on the screen
    clr.l   d5
    
    jsr     InitImage                               ;Draw the image
    movem.l (a7)+,ALL_REG                           ;Restore the stack and return
    rts
    
********************************************************************
*
* Draw the header image for the high score table
*
********************************************************************

DrawHighScoreHeader:
    movem.l ALL_REG,-(a7)                           ;Push registers to the stack
    lea     HighScoreHeader,a0                      ;Get the address of the image
    
    clr.l   d0                                      ;Set the parameters for the display bitmap function
    clr.l   d1                                      ;Start at 0,0 in the image
    clr.l   d2
    clr.l   d3
    
    move.l  WIDTH_OFFSET(a0),d2                     ;Get the full width of the image from the file header
    move.l  d2,d0
    jsr     ByteSwap
    move.l  d0,d2                                   ;Display the full width of the image
    
    move.l  HEIGHT_OFFSET(a0),d3                    ;Get the height of the image from the filer header
    move.l  d3,d0
    jsr     ByteSwap
    move.l  d0,d3                                   ;Display the full height of the image 
    
    clr.l   d0

    clr.l   d4                                      ;Set the location on the screen to display the image
    clr.l   d5
    move.w  #SCREEN_WIDTH,d4
    sub.w   d2,d4
    lsr.l   #1,d4                                   ;Center the image horizontally
    move.w  #HIGH_SCORE_HEADER_OFFSET,d5            ;Use preset Y position
    
    jsr     InitImage                               ;Draw the image
    movem.l (a7)+,ALL_REG                           ;Restore the stack
    rts

********************************************************************
*
* Draw the title image
*
********************************************************************

DrawTitle:
    movem.l ALL_REG,-(a7)                           ;Push registers to the stack
    lea     Title,a0                                ;Get the image address
    
    clr.l   d0                                      ;Set paramters for display bitmap function
    clr.l   d1                                      ;Start at 0,0 of image
    clr.l   d2
    clr.l   d3
    
    move.l  WIDTH_OFFSET(a0),d2                     ;Display full width
    move.l  d2,d0
    jsr     ByteSwap
    move.l  d0,d2
    
    move.l  HEIGHT_OFFSET(a0),d3                    ;Display full height
    move.l  d3,d0
    jsr     ByteSwap
    move.l  d0,d3
    
    clr.l   d0

    clr.l   d4
    clr.l   d5
    move.w  #SCREEN_WIDTH,d4                        ;Center horizontally on screen
    sub.w   d2,d4
    lsr.l   #1,d4
    move.w  #TITLE_OFFSET,d5                        ;Set to predetermined Y position
    
    jsr     InitImage                               ;Display the image
    movem.l (a7)+,ALL_REG                           ;Restore the stack
    rts

********************************************************************
*
* Draw the ground as a rectangle
*
********************************************************************
    
DrawGround:
    move.l  #GROUND_COLOR,d1                        ;Set the color of the ground
    move.l  #SET_FILL_TRAP_CODE,d0
    trap    #15
    
    move.l  #TASK_PEN_COLOR,d0
    trap    #15
    
    move.l  #0,d1                                   ;Set the location on screen of the ground
    move.l  #SCREEN_HEIGHT,d2                       ;Start at bottom of screen
    sub.l   #GROUND_HEIGHT,d2                       ;Move up predetermined height
    move.l  #SCREEN_WIDTH,d3                        ;Use full width of screen
    move.l  #SCREEN_HEIGHT,d4                       ;Fill to the bottom of the screen
    move.l  #DRAW_SQUARE_TRAP_CODE,d0               ;Draw the rectangle
    trap    #15
    
    rts
    
********************************************************************
*
* Draw the header for the UI above the field of play
*
********************************************************************
    
DrawHeader:    
    move.l  #HEADER_BORDER_COLOR,d1                 ;Set the border color for the header and playfield
    move.l  #SET_FILL_TRAP_CODE,d0
    trap    #15
    
    move.l  #TASK_PEN_COLOR,d0
    trap    #15
    
    clr.l   d1                                      ;Draw as a filled rectangle from 0,0
    clr.l   d2
    move.l  #SCREEN_WIDTH,d3                        ;To the full width of the screen
    move.l  #HEADER_HEIGHT,d4                       ;And a predetermined height
    
    move.l  #DRAW_SQUARE_TRAP_CODE,d0               ;Draw rectangle
    trap    #15

    lea     HeaderBackground,a0                     ;Set paramaters for the bitmap background of the header
    move.l  #0,d0                                   ;Start at 0,0
    move.l  #0,d1
    move.l  #SCREEN_WIDTH,d2                        ;Go the full width of the screen
    move.l  #HEADER_HEIGHT-HEADER_BORDER_WIDTH,d3   ;Leave room for the border in the header
    move.l  #0,d4                                   ;Draw at 0,0 on screen
    move.l  #0,d5
    
    jsr     InitImage                               ;Draw the image
    rts
    
********************************************************************
*
* Clear out an area of pixels no longer in use with background color
*
********************************************************************
    
InvalArea:
    movem.l ALL_REG,-(a7)                           ;Push registers to stack
    move.l  #SPACE_COLOR,d1                         ;Set color to background color
    move.l  #SET_PEN_TRAP_CODE,d0
    trap    #15
    move.l  #SET_FILL_TRAP_CODE,d0
    trap    #15
    
    movem.l (a7),ALL_REG                            ;Get previous values from stack for parameters
    move.l  #DRAW_SQUARE_TRAP_CODE,d0
    trap    #15                                     ;Draw the rectangle to clear
    movem.l (a7)+,ALL_REG                           ;Restore the stack
    rts
    
********************************************************************
*
* Repaint the screen with the back buffer
*
********************************************************************
    
PaintScreen:
    move.l  #REPAINT_SCREEN_TRAP_CODE,d0
    trap    #15
    rts

********************************************************************
*
* Reset all game parameters and variables before restarting play
*
********************************************************************
    
ResetGameParamters:
    move.w  #PLAYER_START_X<<FRAC_BITS,PlayerPosX   ;Reset player position
    move.w  #PLAYER_START_Y<<FRAC_BITS,PlayerPosY
    
    move.w  #0,NumActiveEnemies                     ;Reset enemy counts to 0
    move.w  #MAX_NUM_ENEMIES,DeadEnemies
    move.w  #0,EnemySpeedBonus                      ;Reset enemy speed to base
    
    move.w  #0,NumLivePlayerBullets                 ;Reset bullet counts
    
    move.l  #0,Score                                ;Reset score
    move.w  #0,HaveUsedScore                        ;Reset high score input
    move.w  #0,CurrentTableIndex                    ;Reset high score output
    
    move.w  #0,CurrentYSpeed                        ;Reset player speed
    move.w  #0,CurrentXSpeed
    
    rts
    
    

    include 'Player.X68'                            ;Includes to keep organized
    include 'Input.X68'
    include 'DispBMP.X68'
    include 'random.X68'
    include 'Enemy.X68'
    include 'Bullet.X68'
    include 'StarBG.X68'
    include '7Segment.X68'
    include 'Score.X68'
    include 'HighScore.X68'
    
    

HighScoreHeader     incbin  'HighScoreHeader.bmp'   ;Bitmaps to display
HeaderBackground    incbin  'HeaderBackground.bmp'
Background          incbin  'background.bmp'
PlayerSprite        incbin  'player.bmp'
Title               incbin  'Title.bmp'

FrameTimer          dc.l    0                       ;Frame timer for framerate calculations

IsPlaying           dc.b    2                       ;Game state variable

    END    START                                    ;Last line of source

    









*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
