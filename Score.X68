*-----------------------------------------------------------
* Title      : Score
* Written by : Joshua Newell
* Date       : 10/5/18
* Description: Functions and variables for keeping score throughout the game
*-----------------------------------------------------------
ENEMY_VALUE             EQU $20                 ;How much each enemy is worth
SURVIVAL_SCORE          EQU $1                  ;How many points you get per survival bonus
SURVIVAL_SCORE_TIMER    EQU 10                  ;How often you get survival points

********************************************************************
*
* Load and display current score
*
* Using 7 Segment LED to display
* Load each digit of score, display the segment, and go the next digit
*
********************************************************************

GetScore:
    movem.l ALL_REG,-(a7)                       ;Push registers to stack
    move.l  Score,d0                            ;Get the current score
    clr.l   d7

GetSignificantDigits:                           ;Calculate how many significant digits are in current score for looping
    cmp.l   #0,d0   
    beq     SetSignificantDigits                ;If we've run out of digits, set the counter
    add.l   #1,d7                               ;If not, add 1 to our digits counter
    lsr.l   #4,d0                               ;Shift the score right
    bra     GetSignificantDigits                ;Until there are no more non 0 digits
    
SetSignificantDigits:
    move.w  d7,SignificantDigits                ;Set our variable to the counter we used

    beq     NextDigit                           ;If it's 0 digits, don't loop
    sub.w   #1,d7                               ;Set loop counter
    move.l  Score,d1                            ;Load current score
    
GetCurrentDigit:
    move.l  d1,d0                               ;Get the last digit of the current score
    andi    #$0F,d0
    
    jsr     DrawLED                             ;Draw it using the 7 Segment LED
    
NextDigit:
    lsr.l   #4,d1                               ;Shift our score to the right
    dbra    d7,GetCurrentDigit                  ;Loop again if we have more digits to display
    
    movem.l (a7)+,ALL_REG                       ;Restore the stack
    rts
    
********************************************************************
*
* Add to the player score
*
* Store the score as "decimal" values by checking each digit and adding 6 if it is 0xA or higher
*
********************************************************************
    
AddScore:
    movem.l ALL_REG,-(a7)                       ;Push registers to stack
    
    add.l   d0,Score                            ;Add the parameter score to the player score
    
    clr.l   d7
    move.w  SignificantDigits,d7                ;Load our significant digit counter for looping
    sub.w   #1,d7
    move.l  Score,d1                            ;Load player score
    clr.l   d3
    move.l  #$6,d4                              ;Use 6 for 'wrapping' from 0xA to 10
   
ScoreInner:
    move.l  d1,d2
    and.l   #$F,d2                              ;Get our last digit
    cmp.b   #$A,d2                              ;Check if it is 0xA or higher
    blt     ShiftDigit                          ;If not, do nothing

    add.l   d4,Score                            ;Otherwise add 6 in the current digits place to the player score
    add.l   #6,d1                               ;and the last digit in our loop
    
ShiftDigit:    
    lsl.l   #4,d4                               ;Shift the 6 to the most current digit
    lsr.l   #4,d1                               ;Shift the score to check the next digit
    dbra    d7,ScoreInner                       ;Loop again
    
DoAdd:
    jsr     GetScore                            ;Then display our adjusted score
    
    movem.l (a7)+,ALL_REG                       ;Restore the stack
    rts
            
********************************************************************
*
* Check if enough time has passed to award points for surviving, if so, add the points
*
********************************************************************
    
AddSurvivalScore:
    movem.l ALL_REG,-(a7)                           ;Push registers to stack
    jsr     GetTime                                 ;Get the current time
    move.l  SurvivalTimer,d0                        ;Get time since last add
    add.l   #SURVIVAL_SCORE_TIMER,d0                ;add the timer
    cmp.l   d1,d0                       
    bgt     AddSurvivalScoreEnd                     ;If it's too early, don't add
    
    move.l  d1,SurvivalTimer                        ;If we can add, reset the timer to the current time
    move.l  #SURVIVAL_SCORE,d0                      ;Add our score
    jsr     AddScore
    
AddSurvivalScoreEnd:
    movem.l (a7)+,ALL_REG                           ;Restore stack
    rts
    
    

Score               dc.l    0                   ;Player score
SignificantDigits   dc.w    0                   ;Digit counter

SurvivalTimer       dc.l    0                   ;The last time the player received survival score






*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
