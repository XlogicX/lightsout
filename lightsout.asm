;LightsOut

[ORG 0x7c00]
LEFT EQU 75
RIGHT EQU 77
UP EQU 72
DOWN EQU 80
SPACE EQU 0x39

; Init the environment
xor ax, ax                ; make it zero
mov ds, ax                ; DS=0
mov ss, ax                ; stack starts at 0
mov sp, 0x9c00            ; 200h past code start
mov ah, 0xb8              ; text video memory
mov es, ax                ; ES=0xB800
mov al, 0x03
int 0x10
mov ah, 1
mov ch, 0x26  
int 0x10
; Fill in all black
mov cx, 0x07d0            ; whole screens worth
cbw                       ; clear ax (black on black with null char)
xor di, di                ; first coordinate of video mem
rep stosw                 ; push it to video memory

; Draw Grid Background
; each light is 5x3 'pixels' at 5x5 lights. with border, full grid would be 31x21 'pixels'
mov bx, 21			; 21 rows
mov ax, 0x78b2		; initialize border color
mov di, 520			; initialize top-left corner
grid:
mov cx, 31			; A row of 31
rep stosw			; Draw the row
add di, 98			; offset to get to next row
dec bx				; next iteration
jne grid			; repeat if not done

; Draw all lights out
; bx already 0 from above Routine
mov cl, 25
clearboard:
mov byte [board + bx], 0
inc bx
loop clearboard
; Initialize 4 lights turned on that are still in a winnable state
mov word [board + 20], 0x0101
mov word [board + 23], 0x0101

; Evil?
in al,(0x40)            ; Get random
cmp al, 0x10            ; 1 in 16 chance it will be evil
ja evildone            	; If above, then not evil
; Otherwise: Evil (start at unsolvable position)
mov byte [board], 1				; Unsolvable modification
mov byte [lighton + 2], 0x44	; Change lights from yellow to red
evildone:

; Scramble (game plays itself randomely for 255 moves)
mov bp, 0xff              ; Init to 255 rounds of movement
scramble:
  dec bp
  je gameloop               ; Once done, go to main game loop
  in al,(0x40)              ; Get 'random' value
  and al, 3                 ; Only preserve last 2 bits (for 4 possible up/down/left/right moves)
  push word scrambletoggle        ; point of return instead of using call for the below jumps
  ; Do a random tile move based on random results
; cmp al, 0              ; and al,3 already did this comparison
  je up
  cmp al, 1
  je down
  cmp al, 2
  je left
  cmp al, 3
  je right
  scrambletoggle:
  push word scramble
  jmp toggle

gameloop:
; Keyboard handling
mov ah, 1               ; Is there a key
int 0x16                ; ""
jz gameloop              ; If not wait for a key
cbw                     ; clear ax (Get the key)
int 0x16                ; ""
push word gameloop      ; point of return instead of using call
; Get the Keys
cmp ah, UP
je up
cmp ah, DOWN
je down
cmp ah, LEFT
je left
cmp ah, RIGHT
je right
cmp ah, SPACE
je toggle
cmp ah, 0x01
je exit
ret
exit:
  mov ax,0x0002         ; Clear screen
  int 0x10
  int 0x20              ; Return to bootOS
up:
	sub si, 0x100		; move coordinate
	cmp si, -1			; bounds check
	jg done				; if good, no mods needed
	add si, 0x100 		; Otherwise, correct bounds
	jmp done
down:
	add si, 0x100
	cmp si, 0x405
	jl done
	sub si, 0x100
	jmp done
left:
	sub si, 1
	mov ax, si
	cmp al, -1
	jg done
	add si, 1
	jmp done
right:
	add si, 1
	mov ax, si
	cmp al, 5
	jl done
	sub si, 1
	jmp done
toggle:
	call flip		;flip cursored light

	sub si, 0x100			; move up a light
	cmp si, -1				; see if out of bounds
	jg upflip				; if in bounds
	jmp updone				; otherwise don't flip and correct bounds
	upflip: call flip
	updone: add si, 0x100

	add si, 0x100
	cmp si, 0x405
	jl downflip
	jmp downdone
	downflip: call flip
	downdone: sub si, 0x100

	sub si, 1
	mov ax, si
	cmp al, -1
	jg leftflip
	jmp leftdone
	leftflip: call flip
	leftdone: add si, 1

	add si, 1
	mov ax, si
	cmp al, 5
	jl rightflip
	jmp rightdone
	rightflip: call flip
	rightdone: sub si, 1

done:
	call drawboard		; redraw the board
	call cursor			; redraw the cursor over the board
	call wincheck		; check to see if all lights are off
ret

; Routine for setting on/off color
lightoff:
push 0				; 0 for off, but default
jmp lighton_b		; if so, we can draw it
lighton:			; enter on light on possibly
push 0xee00			; 'light-on' character
lighton_b:
call getcoord		; AX has an encoded coord, this gets the di value needed
pop ax				; get color value off the stack into ax
call drawlight		; draw the light
ret

; Routine that gets the upper left coordinate of a 5x5 light
getcoord:
mov di, 0x2aa		; starting corner of first (top left) light
mov cl, ah			; y coord
coordloop1:
add di, 0x280		; for each y, add 0x280
loop coordloop1
mov cl, al			; x coord
coordloop2:
add di, 0xc			; for each x, add 12
loop coordloop2
ret

; Routine for drawing the light, color should be already chosen before entering
drawlight:
mov bx, 3			; 3 rows
lightgrid:
mov cx, 5			; A row of 5
rep stosw			; Draw the row
add di, 150			; offset to get to next row
dec bx				; next iteration
jne lightgrid		; repeat if not done
ret

; Taking the on/off (1 or 0) values of our 25 byte board array and
; drawing them to screen. It may seem like a waste of data/bytes to
; store 1/0 flags in each byte, but this memory does not account
; for any of the 512 byte limit and a decoding routine for packed data
; WOULD account for using the 512 byte limit.
drawboard:
xor ax, ax		; init
xor bx, bx		; init
fillboard:
push ax			; safe keeping for ax and bx, they get mangled in some calls
push bx
mov cl, byte [board + bx]	; Get a light value
cmp cl, 0					; is it off
jne otherlight				; if its not off (on), go and call 'lighton'
call lightoff				; otherwise we call 'lightoff'
jmp nextdraw
otherlight:
call lighton
nextdraw:
pop bx				; restore our ax, and bx values
pop ax
inc ah				; increment our y coordinate
inc bx				; increment to next light value in data array
cmp ah, 5			; is it last column?
jne fillboard		; if not, keep processing
inc al				; increment our x coordinate
cbw					; clear ah/(y coord)
cmp al, 5			; is it the lsat row?
jne fillboard		; if not, keep going
ret

cursor:
mov ax, si			; get encoded light coordinate
call getcoord		; decode it to di value
add di, 164			; adjust to center of light, not upper left corner
mov ah, 0x88		; Make color grey
stosw				; paint it
ret

; This is a routine for just toggling one light
flip:
mov ax, si			; get encoded coordinate into ax
xor bx, bx			; init
mov cl, al			; row into cl
fliploop:
add bx, 5			; add columns for how many are encoded
loop fliploop
add bl, ah			; add rows for how many are encoded
cmp byte [board + bx], 1	; is light on?
je flipoff					; if so, turn off
mov byte [board + bx], 1	; turn light on
ret
flipoff:
mov byte [board + bx], 0	; turn light off
ret

; See if all lights are turned off, if so, do 'winning' sequence.
wincheck:
xor bx, bx				; init
winloop:
mov al, [board + bx]	; check light at current coord
cmp al, 1				; is it on?
je checkdone			; if it as, we haven't won
inc bx					; go to next light
cmp bx, 26				; have we checked all lights?
jl winloop				; if not, keep processing
mov ch, 0x10			; otherwise, win screen, 0x10xx iterations
win:
in al,(0x40)            ; Get random
shl ax, 8				; Get into ah
in al,(0x40)			; Get random again and keep in al (for full ax random)
mov di, ax				; make it the coordinate (but it's also the character)
and di, 0x0fff			; mask coordinate so it's likely within screen
stosw					; print it
mov bx, [0x046C] 	; Get timer state
add bx, 1 			; 1 tick
delay:
cmp [0x046C], bx
jb delay
loop win
int 0x19			; Restart the game after it does a visual for a minute or so
checkdone:
ret

;BIOS sig and padding
times 510-($-$$) db 0
dw 0xAA55

; Board data, pointed to in a memory area after the executable code image. It consumes 25 bytes of data
board:
