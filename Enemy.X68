*-----------------------------------------------------------
* Title      : Enemy
* Written by : Joshua Newell
* Date       : 9/30/18
* Description: Enemy functions, behavior, and variables
*-----------------------------------------------------------
MAX_NUM_ENEMIES     EQU 10                      ;Amount of enemies we can have on the screen at one time
ENEMY_SPEED         EQU 64                      ;The enemies' base speed
ENEMY_WIDTH         EQU 16                      ;The width of the enemy sprite in pixels
ENEMY_HEIGHT        EQU 17                      ;The height of the enemy
ENEMY_SPAWN_CHANCE  EQU 200                     ;The rate at which enemies spawn

ENEMY_SPEED_FACTOR  EQU 2                       ;How much enemies speed up at every interval
ENEMY_SPEED_TIMER   EQU 100                     ;How often enemies speed up

********************************************************************
*
* Determine whether or not to spawn an enemy this frame
*
* Get a random number, compare it to our chance, and spawn
*
********************************************************************

CheckEnemySpawn:
    movem.l         ALL_REG,-(a7)                           ;Push registers to stack
    cmp.w           #MAX_NUM_ENEMIES,NumActiveEnemies       ;Don't calculate random if we're already at the maximum number of enemies
    bge             EndCheckEnemySpawn
    
    jsr             GetRandomByteIntoD6                     ;Get our random number
    divu            #ENEMY_SPAWN_CHANCE,d6                  ;Compare it to our random chance
    cmp.w           #1,d6                                   
    bne             EndCheckEnemySpawn                      ;If we pass, spawn an enemy
    jsr             SpawnEnemy

EndCheckEnemySpawn:    
    movem.l          (a7)+,ALL_REG                          ;Restore stack
    rts

********************************************************************
*
* Spawn an enemy
*
* Randomly choose a Y coordinate in field of play, spawn enemy at right side of screen
*
********************************************************************

SpawnEnemy:
    movem.l         ALL_REG,-(a7)                           ;Push registers to stack
    
    jsr             GetRandomLongIntoD6                     ;Get random for Y location
    
    lea             EnemyPosArray,a0                        ;Get address of enemy array
    clr.l           d0
    move.w          NumActiveEnemies,d0                     ;Get number of active enemies
    lsl             #2,d0                                   ;Multiply by 4 to get number of bytes already in use by active enemies
    add.l           d0,a0                                   ;Add this to enemy array to offset to unused data
    
    move.w          #SCREEN_WIDTH,d0                        ;Get starting X position at right side of screen
    lsl             #FRAC_BITS,d0
    move.w          d0,(a0)
    add.l           #2,a0
    
    move.w          #SCREEN_HEIGHT,d0                       ;Get random starting Y within field of play
    sub.w           #GROUND_HEIGHT,d0
    sub.w           #ENEMY_HEIGHT,d0
    sub.w           #HEADER_HEIGHT,d0                       ;Get range of coordinates
    and.l           #$0000FFFF,d6
    divu            d0,d6                                   ;Divide by random word
    swap            d6                                      ;Set location to remainder
    add.w           #HEADER_HEIGHT,d6                       ;Offset to below header
    lsl             #FRAC_BITS,d6                           ;Shift for fixed point
    move.w          d6,(a0)                                 ;Store location

    sub.w           #1,DeadEnemies                          ;Subtract from dead enemy counter
    add.w           #1,NumActiveEnemies                     ;Add to active enemy counter
    
    movem.l         (a7)+,ALL_REG                           ;Restore stack
    rts
    
********************************************************************
*
* Update enemies
*
* Fly left at constant speed
* If at left of screen, die and adjust array to push empty spot to end
*
********************************************************************
    
MoveEnemies:
    movem.l         ALL_REG,-(a7)                       ;Push registers to stack
    
    move.w          NumActiveEnemies,d0                 ;Get number of active enemies
    beq             EnemyMoveEnd                        ;If it's 0, we don't have any enemies to move
    sub.w           #1,d0                               ;Otherwise, set our loop index
    move.w          d0,d7
    
MoveEnemiesInner:
    lea             EnemyPosArray,a0                    ;Get the address of our enemy array
    move.w          NumActiveEnemies,d0                 ;Get the number of active enemies
    sub.w           #1,d0                               ;Less 1 for 0th position
    sub.w           d7,d0                               ;Subtract our loop index from live enemies to get our array index
    lsl             #2,d0                               ;Multiply by 4 to get number of bytes to offset
    move.w          d0,CurrentIndex                     ;Set this to our current index for the enemy array
    add.w           d0,a0                               ;Add to the array address to offset
        
    move.l          #ENEMY_WIDTH,d2                     ;Get the enemy sprite width and height
    move.l          #ENEMY_HEIGHT,d3
    clr.l           d4
    move.w          (a0),d4                             ;Get the enemy X position
    bgt             EnemyPositive                       ;If it is greater than 0, keep moving
    move.l          #0,d4                               ;If we are 0 or less, set to 0

EnemyPositive:
    lsr             #FRAC_BITS,d4                       ;Get X coordinate in pixels
    move.l          d4,d0                               
    clr.l           d5          
    move.w          2(a0),d5                            ;Get Y coordinate
    lsr             #FRAC_BITS,d5                       ;In pixels
    move.l          d5,d1
    cmp.w           #$FFFF,d5                           ;If set to -1, enemy is dead so skip
    beq             NextEnemy
    
    move.l          a0,d6                               ;Get X position
    
    movem.l         ALL_REG,-(a7)                       ;Push registers to stack
    move.l          d4,d1                               ;Get enemy screen coordinates
    move.l          d5,d2
    move.l          d1,d3
    move.l          d2,d4
    add.l           #ENEMY_WIDTH,d3                     ;Get right and bottom coordinates for Inval
    add.l           #ENEMY_HEIGHT,d4

    jsr             InvalArea                           ;Clear old pixels
    movem.l         (a7)+,ALL_REG                       ;Restore stack
    move.l          d6,a0                               ;Save the X position
    
    cmp             #1,d4                               ;Check if enemy is at left side of screen
    blt             EnemyDie                            ;If so, die
    
    move.l          #ENEMY_SPEED,d0                     ;Otherwise, keep moving left
    add.w           EnemySpeedBonus,d0                  ;Add speed based on how long player has lived
    sub.w           d0,(a0)                             ;Subtract speed from current position
    
DrawEnemy:    
    clr.l           d0                                  ;Now that the position is updated, draw the enemy
    clr.l           d1
    sub.l           #1,d2                               ;Set to -1 for image loop
    move.w          (a0),d4                             ;Get the X position
    lsr             #FRAC_BITS,d4                       ;On screen
    lea             EnemySprite,a0                      ;Get the sprite image address
    jsr             InitImage                           ;Draw the sprite
    
    dbra            d7,MoveEnemiesInner                 ;Go to the next enemy
    bra             EnemyMoveEnd                        ;Finished looping through all enemies
    
EnemyDie:
    add.w           CurrentIndex,a0                     ;The current enemy is dead, go to the next one
    lea             EnemyPosArray,a1                    ;Get the array of enemies
    
    lea             EnemyPosArray,a2                    ;Copy the array of enemies
    add.l           #4,a2                               ;Get the address of the next enemy
    
    move.w          d7,d6                               ;Copy our current loop counter
    ble             EndShift                            ;If we've made it to the end of the array, exit the loop
    
ShiftArray:
    move.l          a1,a2                               ;Loop through array to shift live enemies to front and dead enemies to end
    move.w          NumActiveEnemies,d5
    sub.l           #1,d5
    sub.l           d6,d5                               ;Subtract current index from number of live enemies to get offset
    move.w          #MAX_NUM_ENEMIES,d4                 ;Check if at end of array
    sub.w           #1,d4
    cmp.w           d4,d5
    bge             EndShift                            ;If so exit loop
    lsl             #2,d5                               ;Multiply offset by 4 to get byte offset
    add.l           d5,a2                               ;Add offset to enemy array
    move.l          4(a2),(a2)                          ;Move coordinates down in the array
    
SetBits:
    move.l          #$FFFFFFFF,4(a2)                    ;move -1,-1 to next position
    dbra            d6,ShiftArray                       ;loop again
    
EndShift:    
    add.w           #1,DeadEnemies                      ;Add to dead enemy counter
    sub.w           #1,NumActiveEnemies                 ;Subtract from live enemy counter
    
NextEnemy:
    dbra            d7,MoveEnemiesInner                 ;Go to next enemy movement
    
EnemyMoveEnd:                                           ;All enemies have been moved
    move.w          #MAX_NUM_ENEMIES,d0                 ;See how many enemies are alive
    sub.w           DeadEnemies,d0
    move.w          d0,NumActiveEnemies                 ;Store this
    
    movem.l         (a7)+,ALL_REG                       ;Restore stack
    rts
    
********************************************************************
*
* Check if it is time to add speed to the enemies
*
********************************************************************
    
CheckEnemySpeedUp:
    movem.l         ALL_REG,-(a7)                       ;Push registers to stack
    
    jsr             GetTime                             ;Get the current time
    move.l          EnemySpeedTimer,d0                  ;compare the last time enemy speed was updated to current time
    add.l           #ENEMY_SPEED_TIMER,d0
    cmp.l           d1,d0                               ;If we are above the threshhold
    bge             CheckEnemySpeedUpEnd
    
    move.l          d1,EnemySpeedTimer                  ;Reset the timer
    add.w           #ENEMY_SPEED_FACTOR,EnemySpeedBonus ;Add speed
    
CheckEnemySpeedUpEnd:
    movem.l         (a7)+,ALL_REG                       ;Restore stack
    rts
    
    

EnemySprite         INCBIN  'enemy.bmp'                 ;Enemy sprite
CurrentIndex        dc.w    0                           ;Current index in enemy array
EnemyPosArray       ds.w    MAX_NUM_ENEMIES*2           ;Allocate memory for enemy coordinates

NumActiveEnemies    dc.w    0                           ;Start with 0 active enemies
DeadEnemies         dc.w    MAX_NUM_ENEMIES

EnemySpeedTimer     dc.l    0                           ;Timer for adding speed
EnemySpeedBonus     dc.w    0                           ;Current additional speed




*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
