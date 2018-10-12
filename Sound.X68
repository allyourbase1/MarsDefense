*-----------------------------------------------------------
* Title      : Sound Manager
* Written by : Joshua Newell
* Date       : 10/9/18
* Description: Control sound output for the game
*   Load sounds, play  and stop when called
*-----------------------------------------------------------
LOAD_SOUND_TASK     EQU 74
PLAY_SOUND_TASK     EQU 75
CONTROL_SOUND_TASK  EQU 77

ALL_REG             REG d0-d7/a0-a6
    ORG    $1000
START:                  ; first instruction of program

* Put program code here

    SIMHALT             ; halt simulator
    
LoadSound:
    movem.l     ALL_REG,-(a7)
    
    move.l      LOAD_SOUND_TASK,d0
    move.l      NumLoadedSounds,d1
    
    trap        #15
    
    cmp.l       #0,d0
    beq         LoadSoundEnd
    
    add.l       #1,NumLoadedSounds
    
LoadSoundEnd:    
    movem.l     (a7)+,ALL_REG
    rts

FireSound       dc.b    'Fire.wav',0
ThemeSong       dc.b    'Theme.wav',0
DieSound        dc.b    'Die.wav',0,0

NumLoadedSounds dc.l    0

    END    START        ; last line of source

*~Font name~Courier New~
*~Font size~11~
*~Tab type~1~
*~Tab size~4~
