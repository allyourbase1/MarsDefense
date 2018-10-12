*-----------------------------------------------------------
* Title      : Input Handler
* Written by : Joshua Newell
* Date       : 9/27/2018
* Description: Handle input from a player for game controls
*-----------------------------------------------------------
KEY_IN_TRAP_CODE        EQU 19                          ;Trap code for checking input for specific keys

WASD_BITS               EQU 'W'<<24+'A'<<16+'S'<<8+'D'  ;Keys for player control
FIRE_KEY                EQU $20                         ;Key for firing

********************************************************************
*
* Handle player input
*
* Check if defined keys are pressed and move the player position accordingly
* Limit movement to defined field of play
* Handle acceleration and deceleration
*
********************************************************************

GetInput:
    movem.l d0-d1,-(a7)                                 ;Push registers to stack
    
    jsr     ClearPlayerBackground                       ;Inval the old player location
        
    move.l  #KEY_IN_TRAP_CODE,d0                        ;Check for fire key press
    move.l  #FIRE_KEY,d1
    trap    #15
    
    cmp.b   #$FF,d1                                     ;If it isn't pressed, we can reset our timer for firing
    bne     GetFireUp
    
    jsr     PlayerFire                                  ;If it is, go ahead and try to fire

GetFireUp:    
    move.l  #0,d1                                       ;Get the last key Up into d1
    trap    #15
    swap    d1
    cmp.b   #FIRE_KEY,d1                                ;If it is fire, reset the timer
    bne     GetMoveInput
    
    move.w  #0,PlayerFireTimer
    
GetMoveInput:
    move.l  #KEY_IN_TRAP_CODE,d0                        ;Check for movement key presses
    move.l  #WASD_BITS,d1
    trap    #15
    
    move.b  #1,PlayerMoveState                          ;Update state to currently not moving up/down for animation
    
AddRight:
    cmp.b   $FF,d1                                      ;Check key right first
    bne     AddDown                                     ;If it is not pressed, skip right movement
    ;Move right 
    move.w  #PLAYER_MAX_X,d0                            ;Make sure the player is not at the right edge of play field
    sub.l   #PLAYER_SPRITE_WIDTH,d0
    lsl     #FRAC_BITS,d0
    cmp.w   PlayerPosX,d0
    ble     AddDown                                     ;If so, don't keep moving right
    add.w   #PLAYER_ACCELERATION,CurrentXSpeed          ;Else add right speed
  
AddDown:
    lsr     #8,d1                                       ;Shift the input to check the next key
    cmp.b   $FF,d1                                      ;If down is not pressed
    bne     AddLeft                                     ;Skip
    ;Move down
    move.w  #SCREEN_HEIGHT,d0                           ;Check if player is at bottom of play field
    sub.l   #PLAYER_SPRITE_HEIGHT,d0                    ;Adjust to bottom of player
    sub.l   #GROUND_HEIGHT,d0
    sub.l   #1,d0
    lsl     #FRAC_BITS,d0
    cmp.w   PlayerPosY,d0                               ;If so, skip
    ble     AddLeft                         
    add.w   #PLAYER_ACCELERATION,CurrentYSpeed          ;Else add downward movement
    move.b  #2,PlayerMoveState                          ;Update movement state for animation
    
AddLeft:
    swap    d1                                          ;Check next input key
    cmp.b   $FF,d1
    bne     AddUp                                       ;If no left input, skip
    ;Move Left
    cmp.w   #1<<FRAC_BITS,PlayerScreenX                 ;Check if at edge of screen
    ble     AddUp                                       ;If so, skip
    sub.w   #PLAYER_ACCELERATION,CurrentXSpeed          ;Else, add left motion
    
AddUp:
    lsr     #8,d1                                       ;Check up key press
    cmp.b   $FF,d1
    bne     CalcMovement                                ;If not, skip and calculate movement vector
    ;Move up
    cmp.w   #HEADER_HEIGHT<<FRAC_BITS,PlayerScreenY     ;Check if at top of play field
    ble     InputEnd                                    ;If so, skip
    sub.w   #PLAYER_ACCELERATION,CurrentYSpeed          ;Else, add upward movement
    move.b  #0,PlayerMoveState                          ;Set animation state to moving up
    
CalcMovement:                                           ;Take input and calculate player movement vector
    clr.l   d0
CheckXMin:
    move.w  CurrentXSpeed,d0                            ;Add the X speed to the player position
    move.w  PlayerPosX,d1
    add.w   d0,d1
    
    cmp.w   #1,d1                                       ;Check if this results in out of bounds
    bge     CheckXMax
    cmp.w   #0,d0                                       ;Check if we're moving left
    bgt     CheckXMax   
    move.w  #0,CurrentXSpeed                            ;If so, set X speed to 0 to prevent going out of bounds
    
    move.w  PlayerPosX,d1                               ;Check if the player is all the way at the left edge of screen
    lsr     #FRAC_BITS,d1
    cmp.w   #0,d1
    bgt     CheckXMax                                   ;If not, move on
    move.w  #1<<FRAC_BITS,PlayerPosX                    ;Else set to X=1 so bitmap can be drawn completely and prevent negative positions
    
CheckXMax:
    move.w  PlayerPosX,d1                               ;Add X speed to player position
    add.w   d0,d1
    
    cmp.w   #PLAYER_MAX_X<<FRAC_BITS,d1                 ;Check if out of bounds to the right
    ble     CheckYMin                                   ;If not, X component is ready to add
    cmp.w   #0,d0                                       ;Are we going right?
    ble     CheckYMin                                   ;If not, X is ready to add
    
    move.w  #0,CurrentXSpeed                            ;If we are going right and at the edge, set X speed to 0
    
CheckYMin:
    move.w  CurrentYSpeed,d0                            ;Check Y position + speed against top of play field
    move.w  PlayerPosY,d1
    add.w   d0,d1
    
    cmp.w   #HEADER_HEIGHT<<FRAC_BITS,d1
    bgt     CheckYMax
    cmp.w   #0,d0
    bgt     CheckYMax
    move.w  #0,CurrentYSpeed                            ;If at top and moving up, set Y speed to 0
    
CheckYMax:
    move.w  PlayerPosY,d1                               ;Check Y position + speed against bottom of play field
    add.w   d0,d1
    
    move.w  #PLAYER_MAX_Y<<FRAC_BITS,d2
    cmp.w   d2,d1
    ble     InputEnd
    cmp.w   #0,d0
    ble     InputEnd
    
    move.w  #0,CurrentYSpeed                            ;If moving down and at bottom, set Y speed to 0

InputEnd:
    move.w  CurrentXSpeed,d0                            ;If speed is not 0
    beq     AddXSpeed
    
    cmp.w   #0,d0                                       ;Slow player down
    bgt     SubtractFrictionX                           ;If moving right, subtract friction
    
    add.w   #PLAYER_FRICTION,CurrentXSpeed              ;Else moving left, so add friction
    bra     AddXSpeed
    
SubtractFrictionX:
    sub.w   #PLAYER_FRICTION,CurrentXSpeed
    
AddXSpeed:
    add.w   d0,PlayerPosX                               ;Add the current X speed to the player position
    
    move.w  CurrentYSpeed,d0                            ;Check if Y speed is positive or negative and adjust for friction
    beq     AddYSpeed                                   ;If 0, no need to slow down
    
    cmp.w   #0,d0
    bgt     SubtractFrictionY                           ;If positive, subtract friction
    
    add.w   #PLAYER_FRICTION,CurrentYSpeed              ;If negative, add friction
    bra     AddYSpeed
    
SubtractFrictionY:
    sub.w   #PLAYER_FRICTION,CurrentYSpeed              ;Subtract friction
    
AddYSpeed:
    add.w   d0,PlayerPosY                               ;Add Y speed to player position

    jsr     CheckPlayerCollision                        ;After updating position, check collisions
    movem.l (a7)+,d0-d1
    rts

CurrentXSpeed   dc.w    0                               ;Store current speed for acceleration
CurrentYSpeed   dc.w    0




*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
