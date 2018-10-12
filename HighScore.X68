*-----------------------------------------------------------
* Title      : High Score
* Written by : Joshua Newell
* Date       : 10/7/18
* Description: High score table functions and variables
* Load scores from a file, check if the player's score is higher than any on the table
* If so, have them input their initials and save their score in the correct spot on the table
* Display all the scores to the player at the end of the game
* Start a new game on a key press after the scores are shown
*-----------------------------------------------------------
NUM_SCORE_ENTRIES   EQU 5                               ;How many entries we have in the table

*Note: Cannot change due to file structure handling
NAME_LENGTH         EQU 3                               ;How many characters to allow for name entry

SPACE_CHAR_ASCII    EQU $20                             ;ASCII value of space

CURSOR_COLUMN       EQU 31                              ;Starting coordinates of text for table
CURSOR_ROW          EQU 12

CURSOR_INPUT_ROW    EQU CURSOR_ROW+NUM_SCORE_ENTRIES+2  ;Coordinates to place Input for new entry
CURSOR_INPUT_COLUMN EQU CURSOR_COLUMN-5

NEW_ENTRY_ROW       EQU CURSOR_ROW-3                    ;Coordinates for string to let the player know they made the high score table
NEW_ENTRY_ROW2      EQU CURSOR_ROW-2
NEW_ENTRY_COLUMN    EQU CURSOR_INPUT_COLUMN+4

PRINT_STRING_TASK   EQU 14                              ;Trap codes for Sim68K hardware simulation
PRINT_CHAR_TASK     EQU 6
GET_CHAR_TASK       EQU 5
PRINT_NUMBER_TASK   EQU 15
SET_CURSOR_TASK     EQU 11
OPEN_FILE_TASK      EQU 51
READ_FILE_TASK      EQU 53
WRITE_FILE_TASK     EQU 54
POSITION_FILE_TASK  EQU 55
CLOSE_FILES_TASK    EQU 50
CHECK_INPUT_TASK    EQU 7
KEYBOARD_ECHO_TASK  EQU 12

********************************************************************
*
* Display high score table
*
* Load the file containing the table
* Compare player score to each entry to see if new high score
* Display all scores
* Save the file once complete
*
********************************************************************

DisplayScores:
    movem.l ALL_REG,-(a7)                       ;Push registers to stack
    
    move.l  #KEYBOARD_ECHO_TASK,d0              ;Disable input printing
    move.l  #0,d1
    trap    #15
    move.l  #GET_CHAR_TASK,d0                   ;Clear leftover character from moving in-game
    trap    #15
    move.l  #KEYBOARD_ECHO_TASK,d0              ;Re-enable input printing
    move.l  #1,d1
    trap    #15
    
    move.l  #OPEN_FILE_TASK,d0                  ;Load the file with the table
    lea     HighScoreFileName,a1
    trap    #15
    move.l  d1,FileID
    
    move.l  #READ_FILE_TASK,d0                  ;Read the file and store in memory
    lea     HighScoreFile,a1
    move.l  #NUM_SCORE_ENTRIES*8,d2
    trap    #15
    
    lea     HighScoreFile,a0                    ;Load the address in memory of the file data
    move.l  a0,a3
    lea     TableIndexStrings,a2                ;Load array of prefixes for table display i.e. '1. '
    lea     TempScoreFile,a6                    ;Load address of memory to store data for writing the file 
    move.l  #NUM_SCORE_ENTRIES-1,d7             ;Set loop counter
    
LoadScore:
    move.l  (a0),d0                             ;Get the current score
    
    cmp.w   #0,HaveUsedScore                    ;If we have already input our score this game
    bne     UseTableScore                       ;We can't do it again!
    
    cmp.l   Score,d0                            ;Is the player score higher than this value?
    bgt     UseTableScore                       ;If not, then go ahead and display it!
    
    move.l  Score,d0                            ;Since it's a new high score, load the player score
    move.l  d0,(a6)+                            ;Write this to the temporary data location for writing to the file later
    jsr     GetPlayerName                       ;Have the player input their name
    move.l  d1,(a6)+                            ;Also write this to memory
    bra     PrintEntry                          ;Then print this entry
    
UseTableScore
    add.l   #4,a0                               ;If we're printing the score from the file, increment our address
                                                ;This way we automatically move the old data down when a player gets on the table
    move.l  d0,(a6)+                            ;Write this to memory so we can save it later
    
    move.l  #NAME_LENGTH,d6                     ;Set our loop for displaying the name from the file
    
*NOTE: Instead of using a long here, move byte by byte to make NAME_LENGTH usable
LoadName:
    lsl.l   #8,d1                               ;Shift our name value
    move.b  (a0)+,d1                            ;And add the next character
    dbra    d6,LoadName                         ;Loop until we're through
    
    move.l  d1,(a6)+                            ;Write the name to memory

PrintEntry:                                     ;Display the current entry
    move.l  d0,-(a7)                            ;Push score to stack
    move.l  d1,-(a7)                            ;Push name to stack
    
    move.l  #SET_CURSOR_TASK,d0                 ;Set the position to print the entry
    move.b  #CURSOR_COLUMN,d1                   ;Set X to upper byte of lower word
    lsl.l   #8,d1
    move.b  #CURSOR_ROW,d1                      ;Set Y to lower byte
    add.w   CurrentTableIndex,d1                ;Offset Y for current entry
    trap    #15
    add.w   #1,CurrentTableIndex                ;Increment the index after printing
    
    *Note: Set up loop by byte to load name to fix NAME_LENGTH functionality
    move.l  (a7)+,d1                            ;Pop the name off the stack
    
    move.l  a2,a1                               ;Display the index for the entry
    add.l   #4,a2                               ;Increment the index array
    move.l  #PRINT_STRING_TASK,d0
    trap    #15
    
    move.l  d1,d0                               ;Byte swap the name to print in order by character
    jsr     ByteSwap
    move.l  d0,d1
    move.l  #PRINT_CHAR_TASK,d0                 ;Print name character by character
    *Note: Set up loop here to fix NAME_LENGTH functionality
    trap    #15
    lsr.l   #8,d1
    trap    #15
    lsr.l   #8,d1
    trap    #15
    
    move.l  #SPACE_CHAR_ASCII,d1                ;Print 3 Spaces after name for formatting
    trap    #15
    trap    #15
    trap    #15
    
    move.l  (a7),d1                             ;Get the score from the stack
    move.l  d1,d0
    
    move.l  #7,d6                               ;Set loop counter
   
CountDigits:
    move.l  d0,d2                               ;Copy score
    move.l  d6,d5                               ;Copy loop counter
    sub.l   #1,d5                               ;Decrement one to loop size-1 times
    
ShiftNumber:
    lsr.l   #4,d2                               ;Shift the score all the way right so we only have 1 digit left
    dbra    d5,ShiftNumber
    
    and.l   #$F,d2                              ;If it's 0, print a space instead of the 0
    cmp.b   #0,d2                               
    bne     SetPadding                          ;Once we reach a non-zero digit, we know how many spaces we need
    dbra    d6,CountDigits                      
    
SetPadding:
    move.l  #7,d5                               ;Get the full size of the number
    sub.l   d6,d5                               ;Subtract the number of significant digits
    beq     PrintScore                          ;If we have no leading 0s, print the entire number
    sub.l   #1,d5                               ;Set a loop for printing spaces
    
PrintPadding:
    move.l  #SPACE_CHAR_ASCII,d1                ;Print a space for each leading 0
    move.l  #PRINT_CHAR_TASK,d0
    trap    #15
    dbra    d5,PrintPadding
    
PrintScore:
    move.l  (a7)+,d1                            ;Print score without leading 0s
    move.l  #16,d2
    move.l  #PRINT_NUMBER_TASK,d0
    trap    #15
    
NextScore:
    dbra    d7,LoadScore                        ;Loop all the way back to get the next entry and compare with player score
    
SaveScores:                                     ;The full table is displayed at this point, so save it
    lea     TempScoreFile,a1                    ;Get the address to memory location of new data
    move.l  FileID,d1                           ;Get the ID of the file that we stored after opening it
    move.l  #POSITION_FILE_TASK,d0              ;The pointer to the file moves when reading, so set back 0 to write over data
    move.l  #0,d2
    trap    #15
    
    move.l  #NUM_SCORE_ENTRIES*8,d2             ;Calculate the number of bytes to write to the file
    move.l  #WRITE_FILE_TASK,d0                 ;Write these bytes to the file to save them for next time
    trap    #15
    
    move.l  #CLOSE_FILES_TASK,d0                ;Close all open files
    trap    #15                                 ;This is necessary to actually save the written data to the file
  
WaitingForInput:                                ;After saving the high scores, wait for player input to begin the next game
    jsr     AwaitInput                          ;Wait for any key
    
EndDisplayScores:                               ;We finally made it! All scores displayed and saved!
    movem.l (a7)+,ALL_REG                       ;Restore the stack
    rts
    

********************************************************************
*
* Get the player's name for a new high score entry
*
********************************************************************
    
GetPlayerName:
    move.l  d0,-(a7)                            ;Push parameters to stack
    movem.l d6/d7,-(a7) 
    
    move.l  #SET_CURSOR_TASK,d0                 ;Move the cursor to the proper position
    
    move.b  #NEW_ENTRY_COLUMN,d1                ;Set to the determined position for the new high score entry string
    lsl.l   #8,d1
    move.b  #NEW_ENTRY_ROW,d1
    trap    #15
    
    lea     InputNameString,a1                  ;Print the new high score string
    move.l  #PRINT_STRING_TASK,d0
    trap    #15

    move.l  #SET_CURSOR_TASK,d0
    move.b  #NEW_ENTRY_COLUMN,d1                ;Set to the position for pt 2
    lsl.l   #8,d1
    move.b  #NEW_ENTRY_ROW2,d1
    trap    #15
    
    lea     InputNameString2,a1
    move.l  #PRINT_STRING_TASK,d0               ;Print part 2 of the string
    trap    #15
    
    move.l  #SET_CURSOR_TASK,d0
    move.b  #CURSOR_COLUMN,d1                   ;Set to the index position
    lsl.l   #8,d1
    move.b  #CURSOR_ROW,d1                      ;And at the proper entry
    add.w   CurrentTableIndex,d1
    trap    #15
    
    move.l  a2,a1                               ;Display the current index
    move.l  #PRINT_STRING_TASK,d0
    trap    #15

    jsr     PaintScreen                         ;Repaint the screen so we see where we are on the table
    
    clr.l   d6
    
    move.l  #GET_CHAR_TASK,d0                   ;Get ready for player input
    move.l  #NAME_LENGTH-1,d7                   ;Set loop index
    
*Note: Go byte by byte here to enable NAME_LENGTH functionality
GetPlayerNameInner:
    trap    #15                                 ;Get input
    move.b  d1,d6                               ;Store character input
    
    lsl.l   #8,d6                               ;Shift to make room
    dbra    d7,GetPlayerNameInner               ;Loop for next character
    
    move.l  d6,d1                               ;Copy name to proper register for saving
    
    move.w  #1,HaveUsedScore                    ;Set variable to show that we have already input the new player high score
    movem.l (a7)+,d6/d7                         ;Restore stack
    move.l  (a7)+,d0
    rts
    

********************************************************************
*
* Wait indefinitely for the player to press any key
*
********************************************************************    

AwaitInput:
    movem.l ALL_REG,-(a7)                       ;Push registers to stack
    move.l  #SET_CURSOR_TASK,d0                 ;Display a message to let the player know we are waiting on them
    move.b  #CURSOR_INPUT_COLUMN,d1             ;Print the message in the proper location
    lsl.l   #8,d1
    move.b  #CURSOR_INPUT_ROW,d1
    trap    #15

    move.l  #PRINT_STRING_TASK,d0               ;Display the message
    lea     WaitInputString,a1
    trap    #15
    
    jsr     PaintScreen                         ;Update the screen so the player can see the message
    
AwaitInputInner:
    move.l  #CHECK_INPUT_TASK,d0                ;Check for player input
    trap    #15
    
    cmp.b   #1,d1                               ;If there was any key pressed
    beq     EndAwaitInput                       ;Move on!
    bra     AwaitInputInner                     ;Otherwise, keep waiting
    
EndAwaitInput:
    move.b  #1,IsPlaying                        ;We're playing again!
    movem.l (a7)+,ALL_REG                       ;Restore stack
    rts



HighScoreFileName   dc.b    'HighScores.dat',0,0                ;Name of high score file
FileID              dc.l    0                                   ;ID of file, gotten after opening
    
HighScoreFile       ds.b    NUM_SCORE_ENTRIES*8                 ;Location in memory of file contents
TempScoreFile       ds.b    NUM_SCORE_ENTRIES*8                 ;Location in memory of file contents to write

TableIndexStrings   dc.b    '1. ',0                             ;Strings to output indices for table entries
                    dc.b    '2. ',0
                    dc.b    '3. ',0
                    dc.b    '4. ',0
                    dc.b    '5. ',0
                    
CurrentTableIndex   dc.w    0                                   ;Where we currently are in the table for output
HaveUsedScore       dc.w    0                                   ;If we have already gotten player score or not

InputNameString     dc.b    '  New high score!',0               ;String to tell the player to input their initials for a new high score entry
InputNameString2    dc.b    'Enter your initials',0

WaitInputString     dc.b    'Press any key to play again!',0,0  ;The string to tell the player to push something





*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
