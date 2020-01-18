;LightsOut

; Corner coordinates for each light
;0x02aa 0x02b6 0x02c2 0x02ce 0x02da
;0x052a 0x0536 0x0542 0x054e 0x055a
;0x07aa 0x07b6 0x07c2 0x07ce 0x07da
;0x0a2a 0x0a36 0x0a42 0x0a4e 0x0a5a
;0x0caa 0x0cb6 0x0cc2 0x0cce 0x0cda

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
mov bx, 21			; 17 rows
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

mov word [board + 20], 0x0101
mov word [board + 23], 0x0101

; Evil?
in al,(0x40)              ; Get random
cmp al, 0x10              ; 1 in 16 chance it will be evil
ja evildone            ; If above, then not evil
; Evil (start at unsolvable position)
mov byte [board], 1
mov byte [lighton + 2], 0x44
evildone:

; Scramble
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
	sub si, 0x100
	cmp si, -1
	jg done
	add si, 0x100 
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

	sub si, 0x100	; move up a light
	cmp si, -1		; see if out of bounds
	jg upflip		; if in bounds
	jmp updone
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
	call drawboard
	call cursor
	call wincheck
ret


quit: jmp quit


; Routine for setting on/off color
lightoff:
push 0
jmp lighton_b
lighton:
push 0xee00			; 'light-on' character
lighton_b:
call getcoord
pop ax
call drawlight
ret

; Routine that gets the upper left coordinate of a 5x5 light
getcoord:
mov di, 0x2aa
mov cl, ah
coordloop1:
add di, 0x280
loop coordloop1
mov cl, al
coordloop2:
add di, 0xc
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

drawboard:
xor ax, ax
xor bx, bx
fillboard:
push ax
push bx
mov cl, byte [board + bx]
cmp cl, 0
jne otherlight
call lightoff
jmp nextdraw
otherlight:
call lighton
nextdraw:
pop bx
pop ax
inc ah
inc bx
cmp ah, 5
jne fillboard
inc al
cbw
cmp al, 5
jne fillboard
ret

cursor:
mov ax, si
call getcoord
add di, 164
mov ah, 0x88
stosw
ret

flip:
mov ax, si
xor bx, bx
mov cl, al
fliploop:
add bx, 5
loop fliploop
add bl, ah
cmp byte [board + bx], 1
je flipoff
mov byte [board + bx], 1
ret
flipoff:
mov byte [board + bx], 0
ret

wincheck:
xor bx, bx
winloop:
mov al, [board + bx]
cmp al, 1
je checkdone
inc bx
cmp bx, 26
jl winloop
mov ch, 0x10
win:
in al,(0x40)              ; Get random
shl ax, 8
in al,(0x40)
mov di, ax
and di, 0x0fff
;in al,(0x40)              ; Get random
;shl ax, 8
;in al,(0x40)
stosw
mov bx, [0x046C] ;Get timer state
add bx, 1 ;2 ticks (can be more)
delay:
cmp [0x046C], bx
jb delay
loop win
int 0x19
checkdone:
ret

;BIOS sig and padding
times 510-($-$$) db 0
dw 0xAA55

board:
