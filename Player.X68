*-----------------------------------------------------------
* Title      : Player
* Written by : Joshua Newell
* Date       : 10/1/18
* Description: The functions and variables for the player within the game
*-----------------------------------------------------------
*Note:Currently not implemented
*PLAYER_MAX_SPEED            EQU 64                                                  ;How fast the player can move
PLAYER_ACCELERATION         EQU 17                                                  ;How fast the player accelerates on a key press
PLAYER_FRICTION             EQU 3                                                   ;How fast the player slows down over time

PLAYER_START_X              EQU 25                                                  ;Where on the screen the player starts the game
PLAYER_START_Y              EQU SCREEN_HEIGHT/2

PLAYER_SPRITE_WIDTH         EQU 22                                                  ;Sprite display parameters
PLAYER_SPRITE_HEIGHT        EQU 19
PLAYER_ANIM_TIMER           EQU 4                                                   ;How often the player sprite updates

PLAYER_MAX_X                EQU SCREEN_WIDTH/4                                      ;The line the player cannot cross moving right
PLAYER_MAX_Y                EQU SCREEN_HEIGHT-GROUND_HEIGHT-PLAYER_SPRITE_HEIGHT    ;The lowest screen coordinate the player can move to

********************************************************************
*
* Clear the pixels where the player was last frame
*
* Note: store lastX, lastY - only repaint 3(?) pixels width behind player
********************************************************************

ClearPlayerBackground:    
    clr.l   d1                                  ;Set screen starting X,Y
    clr.l   d2
    move.w  PlayerPosX,d1                       ;Get the current position
    move.w  PlayerPosY,d2
    
    lsr     #FRAC_BITS,d1                       ;Adjust for fixed point to pixel location
    lsr     #FRAC_BITS,d2
    
    move.l  d1,d3                               ;Add size of sprite to Inval entire area
    move.l  d2,d4
    add.l   #PLAYER_SPRITE_WIDTH,d3
    add.l   #PLAYER_SPRITE_HEIGHT,d4
    
    jsr     InvalArea                           ;Clear area of sprite
    rts
    
********************************************************************
*
* Update the player's location in game
*
********************************************************************
    
MovePlayer: 
    lea     PlayerSprite,a0                     ;Get the address of the player sprite
    
    jsr     AnimPlayer                          ;Do the animation - this will return the current frame
    
    move.l  #PLAYER_SPRITE_WIDTH,d2             ;Get the width and height to display
    move.l  #PLAYER_SPRITE_HEIGHT,d3
    
    move.w  PlayerPosX,PlayerScreenX            ;Store the up to date X,Y locations on screen
    move.w  PlayerScreenX,d4
    lsr     #FRAC_BITS,d4                       ;Adjust for fixed point to pixel coordinates
    move.w  PlayerPosY,PlayerScreenY
    move.w  PlayerScreenY,d5
    lsr     #FRAC_BITS,d5
    
    jsr     InitImage                           ;Draw the image on screen
    rts
    
********************************************************************
*
* Animate the player and return the coordinates of the current frame
*
********************************************************************
    
AnimPlayer:
    clr.l   d0
    sub.b   #1,PlayerAnimTimer                          ;Update the timer
    ble     AnimTimerReset                              ;If it's too soon, don't animate yet
    move.b  PlayerAnimState,d0                          ;Else, get the current frame
    divu    #3,d0                                       ;Set index based on how many states there are
    swap    d0                                          ;to the remainder
    mulu    #PLAYER_SPRITE_WIDTH,d0                     ;Set the X coordinate
    
    clr.l   d1
    move.b  PlayerMoveState,d1                          ;Get the current state of motion
    mulu    #PLAYER_SPRITE_HEIGHT,d1                    ;Set the Y coordinate appropriately
    
    rts
    
AnimTimerReset:
    add.b   #1,PlayerAnimState                          ;Update the animation state
    move.b  #PLAYER_ANIM_TIMER,PlayerAnimTimer          ;Refresh the animation timer
    bra     AnimPlayer                                  ;Return the current frame
    
********************************************************************
*
* Check for any collisions with enemies every frame
*
* Compare boundaries of player with boundaries of every enemy to see if there is any overlap
* If so, we have a collision which will kill the player
*
********************************************************************
    
CheckPlayerCollision:
    movem.l         d0-d7/a0-a6,-(a7)                   ;Push registers to stack
    clr.l           d7
    move.w          NumActiveEnemies,d7                 ;Get our loop index
    sub.w           #1,d7
    lea             EnemyPosArray,a1                    ;Get address of array of enemy positions
    
CheckPlayerCollisionInner:
    move.w          PlayerPosX,d0                       ;Get current player position
    move.w          (a1),d1                             ;Get current enemy position
    add.w           #PLAYER_SPRITE_WIDTH<<FRAC_BITS,d0  ;Check right side of player
    cmp.w           d0,d1
    bgt             CheckPlayerCollisionEnd             ;If player right side is left of enemy, move on
    
    sub.w           #PLAYER_SPRITE_WIDTH<<FRAC_BITS,d0  ;Check left side of player
    add.w           #ENEMY_WIDTH<<FRAC_BITS,d1          ;Against right side of enemy
    cmp.w           d0,d1
    blt             CheckPlayerCollisionEnd             ;If player is to the right of enemy, move on
    
    move.w          PlayerPosY,d0                       ;Get current player Y position
    move.w          2(a1),d1                            ;Get current enemy Y position
    add.w           #PLAYER_SPRITE_HEIGHT<<FRAC_BITS,d0 ;Check bottom of current player
    cmp.w           d0,d1
    bgt             CheckPlayerCollisionEnd             ;If above enemy, move on
    
    sub.w           #PLAYER_SPRITE_HEIGHT<<FRAC_BITS,d0 ;Check top of player
    add.w           #ENEMY_HEIGHT<<FRAC_BITS,d1         ;against bottom of enemy
    cmp.w           d0,d1
    blt             CheckPlayerCollisionEnd             ;If below enemy, move on
    
    move.w          #1,(a1)                             ;If we're here there is an overlap so kill the enemy
    move.b          #0,IsPlaying                        ;And the player
    
CheckPlayerCollisionEnd:
    add.w           #4,a1                               ;We're safe here
    dbra            d7,CheckPlayerCollisionInner        ;So check the next enemy
    
    movem.l         (a7)+,d0-d7/a0-a6                   ;The player lives! Restore the stack
    rts

    
    
PlayerAnimState dc.b    0                               ;Animation index
PlayerAnimTimer dc.b    PLAYER_ANIM_TIMER               ;Animation timer
PlayerMoveState dc.b    1                               ;State for player vertical movement for animation

PlayerPosX      dc.w    PLAYER_START_X<<FRAC_BITS       ;Current player position
PlayerPosY      dc.w    PLAYER_START_Y<<FRAC_BITS
PlayerScreenX   dc.w    PLAYER_START_X<<FRAC_BITS       ;Last drawn player position
PlayerScreenY   dc.w    PLAYER_START_Y<<FRAC_BITS








*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
