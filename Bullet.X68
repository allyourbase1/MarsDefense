*-----------------------------------------------------------
* Title      : Bullet
* Written by : Joshua Newell
* Date       : 10/1/18
* Description: Control bullet movement and collisions
*-----------------------------------------------------------
BULLET_SPEED            EQU 200                                 ;The speed of the bullets
BULLET_WIDTH            EQU 4                                   ;Dimensions in pixels of the bullet
BULLET_HEIGHT           EQU 4

DRAW_ELLIPSE_TRAP_CODE  EQU 88                                  ;Sim68K task for drawing ellipses

MAX_PLAYER_BULLETS      EQU 10                                  ;Maximum number of bullets active at one time
PLAYER_FIRE_TIMER       EQU 10                                  ;Timer for holding fire button down

********************************************************************
*
* Called when the fire key is pressed
* Check the timer and bullet count, fire if we can!
*
********************************************************************

PlayerFire:
    movem.l         ALL_REG,-(a7)                               ;Push registers to stack
    
    cmp.w           #MAX_PLAYER_BULLETS,NumLivePlayerBullets    ;Make sure we are not at bullet capacity
    bge             EndPlayerFire
    
    cmp.w           #0,PlayerFireTimer                          ;Make sure we are not waiting on the debounce timer
    bgt             EndPlayerFire
    
    lea             PlayerBullets,a0                            ;Get the bullets array
    move.w          NumLivePlayerBullets,d0                     ;Offset to first empty position
    lsl             #2,d0
    add.w           d0,a0
    
    move.l          #PLAYER_SPRITE_WIDTH,d0                     ;Set position to spawn bullet
    lsl             #FRAC_BITS,d0
    add.w           PlayerPosX,d0
    move.w          d0,(a0)                                     ;Initialize X at right side of player
    move.l          #PLAYER_SPRITE_HEIGHT,d0                    ;Initialize Y at center of player
    lsr             #1,d0
    lsl             #FRAC_BITS,d0
    add.w           PlayerPosY,d0
    move.w          d0,2(a0)
    
    add.w           #1,NumLivePlayerBullets                     ;Set counters
    sub.w           #1,NumDeadPlayerBullets
    move.w          #PLAYER_FIRE_TIMER,PlayerFireTimer          ;Reset timer
       
EndPlayerFire:
    sub.w           #1,PlayerFireTimer                          ;Decrement timer until we can fire again
    movem.l         (a7)+,ALL_REG                               ;Restore stack
    rts

********************************************************************
*
* Update all player bullets
* Move right at speed and check for collisions
*
********************************************************************
    
UpdateBullets:
    movem.l         ALL_REG,-(a7)                               ;Push registers to stack
    cmp.w           #0,NumLivePlayerBullets                     ;If there are no active bullets, end loop
    ble             EndUpdateBullets
    
    lea             PlayerBullets,a0                            ;Initialize loop for all bullets
    clr.l           d7
    move.w          NumLivePlayerBullets,d7
    sub.w           #1,d7
    
UpdateBulletsInner:
    clr.l           d1
    clr.l           d2
    
    jsr             InvalBullet                                 ;Inval old bullet location
    jsr             CheckPlayerBulletCollision                  ;Check for collisions
    
    move.w          (a0),d0                                     ;Get current X position
    lsr             #FRAC_BITS,d0
    cmp.w           #SCREEN_WIDTH,d0
    bge             ClearBullet                                 ;Remove bullet if off screen right
        
MoveBullet:
    move.l          #1,d0                                       ;Set parameters for drawing the bullet
    move.l          #1,d1                                       ;Image X,Y
    add.w           #BULLET_SPEED,(a0)                          ;Update X position + speed
    move.l          #BULLET_WIDTH,d2                            ;Image width,height
    move.l          #BULLET_HEIGHT,d3
    move.w          (a0),d4                                     ;Screen X,Y
    lsr             #FRAC_BITS,d4
    move.w          2(a0),d5
    lsr             #FRAC_BITS,d5
    move.l          a0,a1
    lea             BulletImg,a0                                ;Bullet image
    jsr             InitImage                                   ;Draw the bullet
    move.l          a1,a0
    
    add.l           #4,a0                                       ;Move to the next bullet
    
    dbra            d7,UpdateBulletsInner                       ;Loop
    
    movem.l         (a7)+,ALL_REG                               ;Restore stack
    rts
    
********************************************************************
*
* Remove the now dead bullet from the array
* Shift the array so the empty position is at the end
*
********************************************************************
    
ClearBullet:
    move.l          d7,d6                                       ;Get current position in array
    move.l          a0,a1                                       ;Get bullet array
    
ShiftPlayerBulletArray:
    move.l          4(a0),(a0)+                                 ;Move contents of next bullet to current
    dbra            d6,ShiftPlayerBulletArray                   ;Do this until the end of the array
    
    move.l          #$FFFFFFFF,-4(a0)                           ;Set last element to -1
    sub.w           #1,NumLivePlayerBullets                     ;Set counters to one less active bullet
    add.w           #1,NumDeadPlayerBullets
    move.l          a1,a0
    dbra            d7,UpdateBulletsInner                       ;Loop back into moving bullets

EndUpdateBullets:  
    movem.l         (a7)+,ALL_REG                               ;Restore stack
    rts
    
********************************************************************
*
* Check if the bullet hits any enemy
* Check bounds of bullet against bounds of each enemy
* Kill both if there is a collision and add score
*
********************************************************************
    
CheckPlayerBulletCollision:
    movem.l         ALL_REG,-(a7)                               ;Push registers to stack
    clr.l           d7
    move.w          NumActiveEnemies,d7                         ;Set up loop through enemies
    sub.w           #1,d7
    lea             EnemyPosArray,a1
    
CheckPlayerBulletCollisionInner:
    clr.l           d0                                          ;Check all four sides of bullet against all four sides of current enemy
    move.w          (a0),d0                                     ;Get current X
    clr.l           d1
    move.w          (a1),d1                                     ;Get current enemy X
    add.w           #BULLET_WIDTH<<FRAC_BITS,d0                 ;Compare right side of bullet with left side of enemy
    cmp.w           d0,d1
    bgt             CheckPlayerBulletCollisionEnd               ;If to the left of enemy, skip
    
    sub.w           #BULLET_WIDTH<<FRAC_BITS,d0                 ;Compare left side of bullet with right side of enemy
    add.w           #ENEMY_WIDTH<<FRAC_BITS,d1
    cmp.w           d0,d1
    blt             CheckPlayerBulletCollisionEnd               ;If past enemy, skip
    
    move.w          2(a0),d0                                    ;Get current Y
    move.w          2(a1),d1                                    ;Get current enemy Y
    add.w           #BULLET_HEIGHT<<FRAC_BITS,d0                ;Check bottom of bullet with top of enemy
    cmp.w           d0,d1
    bgt             CheckPlayerBulletCollisionEnd               ;If above, skip
    
    sub.w           #BULLET_HEIGHT<<FRAC_BITS,d0                ;Check top of bullet with bottom of enemy
    add.w           #ENEMY_HEIGHT<<FRAC_BITS,d1
    cmp.w           d0,d1
    blt             CheckPlayerBulletCollisionEnd               ;If below, skip
    
    move.w          #SCREEN_WIDTH,d0                            ;We have a collision!
    add.w           #BULLET_WIDTH,d0                            ;Move the bullet to the right of the screen, the next frame it will be killed by update
    lsl             #FRAC_BITS,d0
    move.w          d0,(a0)
    
    move.w          (a1),d1                                     ;Get the current position, width, and height of the enemy we collided with
    lsr             #FRAC_BITS,d1
    move.w          2(a1),d2
    lsr             #FRAC_BITS,d2
    move.l          #ENEMY_WIDTH,d3
    move.l          #ENEMY_HEIGHT,d4
    add.l           d1,d3
    add.l           d2,d4
    
    jsr             InvalArea                                   ;Clear the old image from the screen
    move.l          #ENEMY_VALUE,d0                             ;Add score for the kill
    jsr             AddScore
    
    move.w          #$F000,(a1)                                 ;Move the enemy to the left of the screen, it will be cleaned up next frame
    
CheckPlayerBulletCollisionEnd:
    add.w           #4,a1                                       ;Go to next bullet object
    dbra            d7,CheckPlayerBulletCollisionInner          ;And loop
    
    movem.l         (a7)+,ALL_REG                               ;Restore stack
    rts
    
InvalBullet:
    move.w          (a0),d1                                     ;Clear the old bullet pixels
    lsr             #FRAC_BITS,d1                               ;Get X,Y, width, height
    move.w          2(a0),d2
    lsr             #FRAC_BITS,d2
    move.l          #BULLET_WIDTH,d3
    move.l          #BULLET_HEIGHT,d4
    add.l           d1,d3
    add.l           d2,d4
    
    jsr             InvalArea                                   ;Clear the area
    rts



BulletImg               incbin  'Bullet.bmp'                    ;The bullet sprite
PlayerBullets           ds.w    MAX_PLAYER_BULLETS*2            ;The array of player bullets
NumLivePlayerBullets    dc.w    0                               ;Counters for bullet states
NumDeadPlayerBullets    dc.w    MAX_PLAYER_BULLETS
PlayerFireTimer         dc.w    0                               ;Timer for debouncing if fire key is held







*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
