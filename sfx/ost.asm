;-------------------------------------------------------------------------------
;   unit struct
;-------------------------------------------------------------------------------
struc su_unit
    .state      resd    8
    .ports      resd    8
    .size:
endstruc

;-------------------------------------------------------------------------------
;   voice struct
;-------------------------------------------------------------------------------
struc su_voice
    .note       resd    1
    .sustain    resd    1
    .inputs     resd    8
    .reserved   resd    6 ; this is done to so the whole voice is 2^n long, see polyphonic player
    .workspace  resb    63 * su_unit.size
    .size:
endstruc

;-------------------------------------------------------------------------------
;   synthworkspace struct
;-------------------------------------------------------------------------------
struc su_synthworkspace
    .curvoices  resb    32      ; these are used by the multitrack player to store which voice is playing on which track
    .left       resd    1
    .right      resd    1
    .aux        resd    6       ; 3 auxiliary signals
    .voices     resb    32 * su_voice.size
    .size:
endstruc

;-------------------------------------------------------------------------------
;   su_delayline_wrk struct
;-------------------------------------------------------------------------------
struc   su_delayline_wrk
    .dcin       resd    1
    .dcout      resd    1
    .filtstate  resd    1
    .buffer     resd    65536
    .size:
endstruc

;-------------------------------------------------------------------------------
;   su_sample_offset struct
;-------------------------------------------------------------------------------
struc   su_sample_offset  ; length conveniently 8 bytes, so easy to index
    .start      resd    1
    .loopstart  resw    1
    .looplength resw    1
    .size:
endstruc
;-------------------------------------------------------------------------------
;   Uninitialized data: The synth object
;-------------------------------------------------------------------------------
section .synth_object bss align=256
su_synth_obj:
    resb    su_synthworkspace.size
    resb    16*su_delayline_wrk.size


;-------------------------------------------------------------------------------
;   su_render_song function: the entry point for the synth
;-------------------------------------------------------------------------------
;   Has the signature su_render_song(void *ptr), where ptr is a pointer to
;   the output buffer. Renders the compile time hard-coded song to the buffer.
;   Stack:  output_ptr
;-------------------------------------------------------------------------------
section .su_render_song code align=1
global su_render_song
su_render_song:    
    push    rcx		; Stack: OutputBufPtr, retaddr_su_render_song 
    push    rdi		; Stack: NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    push    rsi		; Stack: NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    push    rbx		; Stack: NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    push    rbp		; Stack: NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song  ; rcx = ptr to buf. rdi,rsi,rbx,rbp  nonvolatile
    xor     eax, eax
    push    35655680		; Stack: VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    push    1		; Stack: RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    push    rax		; Stack: GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
su_render_rowloop:                      ; loop through every row in the song
        push    rax		; Stack: Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
        call    su_update_voices   ; update instruments for the new row
        xor     eax, eax                ; ecx is the current sample within row
su_render_sampleloop:                   ; loop through every sample in the row
            push    rax		; Stack: Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
            push    260538436		; Stack: PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song  ; does the next voice reuse the current opcodes?
            push    28		; Stack: VoicesRemain, PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
            mov     rdx, qword su_synth_obj                       ; rdx points to the synth object
            mov     rbx, qword su_patch_opcodes           ; COM points to vm code
            mov     rsi, qword su_patch_operands             ; VAL points to unit params
            mov     rcx, qword su_synth_obj + su_synthworkspace.size - su_delayline_wrk.filtstate
            lea     rbp, [rdx + su_synthworkspace.voices]            ; WRK points to the first voice
            call    su_run_vm ; run through the VM code
            pop     rax      ; rax = VoicesRemain, Stack: PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
            pop     rax      ; rax = PolyphonyBitmask, Stack: Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
            mov     rdi, [rsp + 72] ; edi containts ptr
            mov     rsi, qword su_synth_obj + su_synthworkspace.left
            movsd   ; copy left channel to output buffer
            movsd   ; copy right channel to output buffer
            mov     [rsp + 72], rdi ; save back the updated ptr
            lea     rdi, [rsi-8]
            xor     eax, eax
            stosd   ; clear left channel so the VM is ready to write them again
            stosd   ; clear right channel so the VM is ready to write them again
                    ; *ptr++ = left, *ptr++ = right
            pop     rax      ; rax = Sample, Stack: Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
            inc     dword [rsp + 8] ; increment global time, used by delays
            inc     eax
            cmp     eax, 861
            jl      su_render_sampleloop
        pop     rax      ; rax = Row, Stack: GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song                   ; Stack: pushad ptr
        inc     eax
        cmp     eax, 8112
        jl      su_render_rowloop
    ; rewind the stack the entropy of multiple pop rax is probably lower than add
    pop     rax      ; rax = GlobalTick, Stack: RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    pop     rax      ; rax = RandSeed, Stack: VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    pop     rax      ; rax = VoiceTrackBitmask, Stack: NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    ; Windows64 ABI, rdi rsi rbx rbp non-volatile    
    pop     rbp      ; rbp = NonVolatileRbp, Stack: NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    pop     rbx      ; rbx = NonVolatileRbx, Stack: NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    pop     rsi      ; rsi = NonVolatile, Stack: NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    pop     rdi      ; rdi = NonVolatileRsi, Stack: OutputBufPtr, retaddr_su_render_song 
    pop     rcx      ; rcx = OutputBufPtr, Stack: retaddr_su_render_song 
    ret

;-------------------------------------------------------------------------------
;   su_update_voices function: polyphonic & chord implementation
;-------------------------------------------------------------------------------
;   Input:      eax     :   current row within song
;   Dirty:      pretty much everything
;-------------------------------------------------------------------------------
section .su_update_voices code align=1
su_update_voices:
; The more complicated implementation: one track can trigger multiple voices
    xor     edx, edx
    mov     ebx, 48                   ; we could do xor ebx,ebx; mov bl,PATTERN_SIZE, but that would limit patternsize to 256...
    div     ebx                                 ; eax = current pattern, edx = current row in pattern
    
lea     r9, [rel su_tracks]
    lea     rsi, [r9+rax]  ; esi points to the pattern data for current track
    xor     eax, eax                            ; eax is the first voice of next track
    xor     ebx, ebx                            ; ebx is the first voice of current track
    mov     rbp, qword su_synth_obj           ; ebp points to the current_voiceno array
su_update_voices_trackloop:
        movzx   eax, byte [rsi]                     ; eax = current pattern
        imul    eax, 48                   ; eax = offset to current pattern data    
    lea     r9, [rel su_patterns]
    lea		r9, [r9 + rax]
        movzx   eax,byte [r9 + rdx]  ; eax = note
        push    rdx                                 ; Stack: ptrnrow
        xor     edx, edx                            ; edx=0
        mov     ecx, ebx                            ; ecx=first voice of the track to be done
su_calculate_voices_loop:                           ; do {
        bt      dword [rsp + 32 + 8],ecx ; test voicetrack_bitmask// notice that the incs don't set carry
        inc     edx                                 ;   edx++   // edx=numvoices
        inc     ecx                                 ;   ecx++   // ecx=the first voice of next track
        jc      su_calculate_voices_loop            ; } while bit ecx-1 of bitmask is on
        push    rcx                                 ; Stack: next_instr ptrnrow
        cmp     al, 1                    ; anything but hold causes action
        je      short su_update_voices_nexttrack
        mov     cl, byte [rbp]
        mov     edi, ecx
        add     edi, ebx
        shl     edi, 12           ; each unit = 64 bytes and there are 1<<MAX_UNITS_SHIFT units + small header    
    lea     r9, [rel su_synth_obj]
        and     dword [r9 + su_synthworkspace.voices + su_voice.sustain + rdi], 0 ; set the voice currently active to release; notice that it could increment any number of times
        cmp     al, 1                    ; if cl < HLD (no new note triggered)
        jl      su_update_voices_nexttrack          ;   goto nexttrack
        inc     ecx                                 ; curvoice++
        cmp     ecx, edx                            ; if (curvoice >= num_voices)
        jl      su_update_voices_skipreset
        xor     ecx,ecx                             ;   curvoice = 0
su_update_voices_skipreset:
        mov     byte [rbp],cl
        add     ecx, ebx
        shl     ecx, 12                           ; each unit = 64 bytes and there are 1<<6 units + small header
        lea     rdi,[r9 + su_synthworkspace.voices + rcx]
        stosd                                       ; save note
        stosd                                       ; save release
        mov     ecx, (su_voice.size - su_voice.inputs)/4
        xor     eax, eax
        rep stosd                                   ; clear the workspace of the new voice, retriggering oscillators
su_update_voices_nexttrack:
        pop     rbx                                 ; ebx=first voice of next instrument, Stack: ptrnrow
        pop     rdx                                 ; edx=patrnrow
        add     rsi, 169
        inc     rbp        
        lea     r9, [rel su_synth_obj + 24]
        cmp     rbp,r9
        jl      su_update_voices_trackloop
    ret

;-------------------------------------------------------------------------------
;   su_run_vm function: runs the entire virtual machine once, creating 1 sample
;-------------------------------------------------------------------------------
;   Input:      su_synth_obj.left   :   Set to 0 before calling
;               su_synth_obj.right  :   Set to 0 before calling
;               _CX                 :   Pointer to delay workspace (if needed)
;               _DX                 :   Pointer to synth object
;               COM                 :   Pointer to opcode stream
;               VAL                 :   Pointer to operand stream
;               WRK                 :   Pointer to the last workspace processed
;   Output:     su_synth_obj.left   :   left sample
;               su_synth_obj.right  :   right sample
;   Dirty:      everything
;-------------------------------------------------------------------------------
section .su_run_vm code align=1
su_run_vm:    
    push    rcx		; Stack: DelayWorkSpace, retaddr_su_run_vm, VoicesRemain, PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    push    rdx		; Stack: Synth, DelayWorkSpace, retaddr_su_run_vm, VoicesRemain, PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    push    rbx		; Stack: OpcodeStream, Synth, DelayWorkSpace, retaddr_su_run_vm, VoicesRemain, PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    push    rbp		; Stack: Voice, OpcodeStream, Synth, DelayWorkSpace, retaddr_su_run_vm, VoicesRemain, PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    push    rsi		; Stack: OperandStream, Voice, OpcodeStream, Synth, DelayWorkSpace, retaddr_su_run_vm, VoicesRemain, PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
su_run_vm_loop:                                     ; loop until all voices done
    movzx   edi, byte [rbx]                         ; edi = command byte
    inc     rbx                                     ; move to next instruction
    add     rbp, su_unit.size                       ; move WRK to next unit
    shr     edi, 1                                  ; shift out the LSB bit = stereo bit
    je      su_run_vm_advance                ; the opcode is zero, jump to advance
    mov     rdx, [rsp + 8]         ; reset INP to point to the inputs part of voice
    pushf                                          ; push flags to save carry = stereo bit
    add     rdx, su_voice.inputs
    xor     ecx, ecx                                ; counter = 0
    xor     eax, eax                                ; clear out high bits of eax, as lodsb only sets al
su_transform_operands_loop:    
    lea     r9, [rel su_vm_transformcounts-1]
    cmp     cl, byte [r9+rdi]   ; compare the counter to the value in the param count table
    je      su_transform_operands_out
    lodsb                                           ; load the operand from VAL stream
    push    rax                                     ; push it to memory so FPU can read it
    fild    dword [rsp]                             ; load the operand value to FPU stack    
    lea     r9, [rel FCONST_0_00781250]
    fmul    dword [r9]          ; divide it by 128 (0 => 0, 128 => 1.0)
    fadd    dword [rbp+su_unit.ports+rcx*4]         ; add the modulations in the current workspace
    fstp    dword [rdx+rcx*4]                       ; store the modulated value in the inputs section of voice
    xor     eax, eax
    mov     dword [rbp+su_unit.ports+rcx*4], eax    ; clear out the modulation ports
    pop     rax
    inc     ecx
    jmp     su_transform_operands_loop
su_transform_operands_out:
    popf                                          ; pop flags for the carry bit = stereo bit    
    lea     r9, [rel su_vm_jumptable-8]
    call    [r9+rdi*8]       ; call the function corresponding to the instruction
    jmp     su_run_vm_loop
su_run_vm_advance:
    mov     rbp, [rsp + 8]         ; WRK points to start of current voice
    add     rbp, su_voice.size              ; move to next voice
    mov     [rsp + 8], rbp         ; update the pointer in the stack to point to the new voice
    mov     ecx, [rsp + 48]     ; ecx = how many voices remain to process
    dec     ecx                             ; decrement number of voices to process
    bt      dword [rsp + 56], ecx ; if voice bit of su_polyphonism not set
    jnc     su_op_advance_next_instrument   ; goto next_instrument
    mov     rsi, [rsp] ; if it was set, then repeat the opcodes for the current voice
    mov     rbx, [rsp + 16]
su_op_advance_next_instrument:
    mov     [rsp], rsi ; save current VAL as a checkpoint
    mov     [rsp + 16], rbx ; save current COM as a checkpoint
su_op_advance_finish:
    mov     [rsp + 48], ecx
    jne     su_run_vm_loop  ; ZF was set by dec ecx    
    pop     rsi      ; rsi = OperandStream, Stack: Voice, OpcodeStream, Synth, DelayWorkSpace, retaddr_su_run_vm, VoicesRemain, PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    pop     rbp      ; rbp = Voice, Stack: OpcodeStream, Synth, DelayWorkSpace, retaddr_su_run_vm, VoicesRemain, PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    pop     rbx      ; rbx = OpcodeStream, Stack: Synth, DelayWorkSpace, retaddr_su_run_vm, VoicesRemain, PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    pop     rdx      ; rdx = Synth, Stack: DelayWorkSpace, retaddr_su_run_vm, VoicesRemain, PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    pop     rcx      ; rcx = DelayWorkSpace, Stack: retaddr_su_run_vm, VoicesRemain, PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    ret
;-------------------------------------------------------------------------------
;   ADDP opcode: add the two top most signals on the stack and pop
;-------------------------------------------------------------------------------
;   Mono:   a b -> a+b
;   Stereo: a b c d -> a+c b+d
;-------------------------------------------------------------------------------
section .su_op_addp code align=1
su_op_addp:
    faddp   st1, st0
    ret

;-------------------------------------------------------------------------------
;   LOADNOTE opcode: load the current note, scaled to [-1,1]
;-------------------------------------------------------------------------------
;   Mono:   (empty) -> n, where n is the note
;   Stereo: (empty) -> n n
;-------------------------------------------------------------------------------
section .su_op_loadnote code align=1
su_op_loadnote:
    jnc     su_op_loadnote_mono
    call    su_op_loadnote_mono
    su_op_loadnote_mono:
    fild    dword [rdx-su_voice.inputs+su_voice.note]
    
lea     r9, [rel FCONST_0_00781250]
    fmul    dword [r9]  ; s=n/128.0
    
lea     r9, [rel FCONST_0_500000]
    fsub    dword [r9]        ; s-.5
    fadd    st0, st0                        ; 2*s-1
    ret

;-------------------------------------------------------------------------------
;   MULP opcode: multiply the two top most signals on the stack and pop
;-------------------------------------------------------------------------------
;   Mono:   a b -> a*b
;   Stereo: a b c d -> a*c b*d
;-------------------------------------------------------------------------------
section .su_op_mulp code align=1
su_op_mulp:
    jnc     su_op_mulp_mono
    fmulp   st2, st0
    fmulp   st2, st0
    ret
su_op_mulp_mono:
    fmulp   st1
    ret


;-------------------------------------------------------------------------------
;   HOLD opcode: sample and hold the signal, reducing sample rate
;-------------------------------------------------------------------------------
;   Mono version:   holds the signal at a rate defined by the freq parameter
;   Stereo version: holds both channels
;-------------------------------------------------------------------------------
section .su_op_hold code align=1
su_op_hold:
    fld     dword [rdx]    ; f x
    fmul    st0, st0                        ; f^2 x
    fchs                                    ; -f^2 x
    fadd    dword [rbp]              ; p-f^2 x
    fst     dword [rbp]              ; p <- p-f^2
    fldz                                    ; 0 p x
    fucomip st1                             ; p x
    fstp    dword [rsp-4]                   ; t=p, x
    jc      short su_op_hold_holding        ; if (0 < p) goto holding
    fld1                                    ; 1 x
    fadd    dword [rsp-4]                   ; 1+t x
    fstp    dword [rbp]   ; x
    fst     dword [rbp+4] ; save holded value
    ret                                     ; x
su_op_hold_holding:
    fstp    st0                             ;
    fld     dword [rbp+4] ; x
    ret

;-------------------------------------------------------------------------------
;   INVGAIN opcode: apply inverse gain on the signal
;-------------------------------------------------------------------------------
;   Mono:   x   ->  x/g
;   Stereo: l r ->  l/g r/g
;-------------------------------------------------------------------------------
section .su_op_invgain code align=1
su_op_invgain:
    fld     dword [rdx] ; g l (r)
    fdiv    st2, st0                             ; g l r/g
su_op_invgain_mono:
    fdivp   st1, st0                             ; l/g (r/)
    ret

;-------------------------------------------------------------------------------
;   FILTER opcode: perform low/high/band-pass/notch etc. filtering on the signal
;-------------------------------------------------------------------------------
;   Mono:   x   ->  filtered(x)
;   Stereo: l r ->  filtered(l) filtered(r)
;-------------------------------------------------------------------------------
section .su_op_filter code align=1
su_op_filter:
    lodsb ; load the flags to al
    call    su_effects_stereohelper
    fld     dword [rdx + 4] ; r x
    fld     dword [rdx]; f r x
    fmul    st0, st0                        ; f2 x (square the input so we never get negative and also have a smoother behaviour in the lower frequencies)
    fst     dword [rbp+12]                   ; f2 r x
    fmul    dword [rbp+8]  ; f2*b r x
    fadd    dword [rbp]   ; f2*b+l r x
    fst     dword [rbp]   ; l'=f2*b+l r x
    fsubp   st2, st0                        ; r x-l'
    fmul    dword [rbp+8]  ; r*b x-l'
    fsubp   st1, st0                        ; x-l'-r*b    
    lea     r9, [rel FCONST_0_500000]
    fadd    dword [r9]           ; add and sub small offset to prevent denormalization
    fsub    dword [r9]           ; See for example: https://stackoverflow.com/questions/36781881/why-denormalized-floats-are-so-much-slower-than-other-floats-from-hardware-arch
    fst     dword [rbp+4]  ; h'=x-l'-r*b
    fmul    dword [rbp+12]                   ; f2*h'
    fadd    dword [rbp+8]  ; f2*h'+b
    fstp    dword [rbp+8]  ; b'=f2*h'+b
    fldz                                    ; 0
    test    al, byte 0x40
    jz      short su_op_filter_skiplowpass
    fadd    dword [rbp]
su_op_filter_skiplowpass:
    test    al, byte 0x20
    jz      short su_op_filter_skipbandpass
    fadd    dword [rbp+8]
su_op_filter_skipbandpass:
    test    al, byte 0x10
    jz      short su_op_filter_skiphighpass
    fadd    dword [rbp+4]
su_op_filter_skiphighpass:
    test    al, byte 0x08
    jz      short su_op_filter_skipnegbandpass
    fsub    dword [rbp+8]
su_op_filter_skipnegbandpass:
    test    al, byte 0x04
    jz      short su_op_filter_skipneghighpass
    fsub    dword [rbp+4]
su_op_filter_skipneghighpass:
    ret

;-------------------------------------------------------------------------------
;   BELLEQ opcode: perform second order bell eq filtering on the signal
;-------------------------------------------------------------------------------
;   Mono:   x   ->  eq(x)
;   Stereo: l r ->  eq(l) eq(r)
;-------------------------------------------------------------------------------
section .su_op_belleq code align=1
su_op_belleq:
    ; Note: we calculate the gain first because su_power needs temp stack and everything here was crafted to stay altogether below max 4 temp stack
    ; The cost of staying at max 4 stack was a few extra instructions because of stack juggling.
    ; The bell filter biquad coefficients (see go_synth.go):
    ;   b0, b1, b2 = 1+u, -2*cos(w), 1-u
	;   a0, a1, a2 = 1+v, b1, 1-v
    ; where w=freq*freq, u=alpha*A, v=alpha/A, alpha=sin(w)*2*bandwidth, A=gain. The filter is implemented as:
    ;  y = (b0*x+s1)/a0 = ((1+u)*x + s1) / (1+v) = (x+u*x+s1)/(1+v)
    ;  s1' = b1*x - a1*y + s2 = b1*(x-y)+s2 = 2*cos(w)*(y-x)+s2
	;  s2' = b2*x - a2*y = (1-u)*x-(1-v)*y = x-y-u*x+v*y
    fld     dword [rdx + 8]        ; g x    
    lea     r9, [rel FCONST_0_500000]
    fsub    dword [r9]           ; g-0.5 x    
    lea     r9, [rel FCONST_6_643856]
    fmul    dword [r9]   ; (g-0.5)*6.643856189774724 x
    call    su_power                            ; A=2^((g-0.5)*6.643856189774724) x
    fld     dword [rdx] ; f A x
    fmul    st0, st0                                ; f*f A x
    fadd    st0, st0                                ; w=2*f*f
    fsincos                                         ; cos(w) sin(w) A x
    fadd    st0, st0                                ; r=2*cos(w) sin(w) A x
    fld     dword [rdx + 4]   ; b r sin(w) A x
    fadd    st0, st0                                ; 2*b r sin(w) A x
    fmulp   st2, st0                                ; r alpha=sin(w)*2*b A x
	fxch    st0, st1                                ; alpha r A x
    fdivr   st2, st0                                ; alpha r v=alpha/A x
	fmul    st0, st0                                ; alpha*alpha r v x
    fdiv    st0, st2                                ; u=alpha*A r v x
    fld1                                            ; 1 u r v x
    faddp   st3, st0                                ; u r v+1 x
    fmul    st0, st3                                ; u*x r v+1 x
    fld     dword [rbp]                        ; s1 u*x r v+1 x
    fadd    st0, st1                                ; s1+u*x u*x r v+1 x
    fadd    st0, st4                                ; s1+u*x+x u*x r v+1 x
    fdiv    st0, st3                                ; y=(s1+u*x+x)/(v+1) u*x r v+1 x    
    lea     r9, [rel FCONST_0_500000]
    fadd    dword [r9]           ; add and sub small offset to prevent denormalization
    fsub    dword [r9]           ; See for example: https://stackoverflow.com/questions/36781881/why-denormalized-floats-are-so-much-slower-than-other-floats-from-hardware-arch
    fmul    st3, st0                                ; y u*x r v*y+y x
    fsub    st3, st0                                ; y u*x r v*y x
    fxch    st4, st0                                ; x u*x r v*y y
    fsubr   st0, st4                                ; y-x u*x r v*y y
    fmul    st2, st0                                ; y-x u*x r*(y-x) v*y y
    fsubp   st3, st0                                ; u*x r*(y-x) x-y+v*y y
    fsubp   st2, st0                                ; r*(y-x) x-y+v*y-u*x y
    fadd    dword [rbp+4]                      ; s2+r*(y-x) x-y+v*y-u*x y
    fstp    dword [rbp]                        ; x-y+v*y-u*x y
    fstp    dword [rbp+4]                      ; y
    ret
;-------------------------------------------------------------------------------
;   PAN opcode: pan the signal
;-------------------------------------------------------------------------------
;   Mono:   s   ->  s*(1-p) s*p
;   Stereo: l r ->  l*(1-p) r*p
;
;   where p is the panning in [0,1] range
;-------------------------------------------------------------------------------
section .su_op_pan code align=1
su_op_pan:
    jc      su_op_pan_do    ; this time, if this is mono op...
    fld     st0             ;   ...we duplicate the mono into stereo first
su_op_pan_do:
    fld     dword [rdx]    ; p l r
    fld1                                        ; 1 p l r
    fsub    st1                                 ; 1-p p l r
    fmulp   st2                                 ; p (1-p)*l r
    fmulp   st2                                 ; (1-p)*l p*r
    ret

;-------------------------------------------------------------------------------
;   DELAY opcode: adds delay effect to the signal
;-------------------------------------------------------------------------------
;   Mono:   perform delay on ST0, using delaycount delaylines starting
;           at delayindex from the delaytable
;   Stereo: perform delay on ST1, using delaycount delaylines starting
;           at delayindex + delaycount from the delaytable (so the right delays
;           can be different)
;-------------------------------------------------------------------------------
section .su_op_delay code align=1
su_op_delay:
    lodsw                           ; al = delay index, ah = delay count    
    push    rsi		; Stack: DelayVal, retaddr_su_op_delay, OperandStream, Voice, OpcodeStream, Synth, DelayWorkSpace, retaddr_su_run_vm, VoicesRemain, PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    push    rbx		; Stack: DelayCom, DelayVal, retaddr_su_op_delay, OperandStream, Voice, OpcodeStream, Synth, DelayWorkSpace, retaddr_su_run_vm, VoicesRemain, PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    movzx   ebx, al    
    lea     r9, [rel su_delay_times]
    lea     rbx,[r9 + rbx*2]                  ; BX now points to the right position within delay time table
    movzx   esi, word [rsp + 104]          ; notice that we load word, so we wrap at 65536
    mov     rcx, qword [rsp + 56]   ; rbp is now the separate delay workspace, as they require a lot more space
    push    rax                 ; save _ah (delay count)
    fxch                        ; r l
    call    su_op_delay_do      ; D(r) l        process delay for the right channel
    pop     rax                 ; restore the count for second run
    fxch                        ; l D(r)
su_op_delay_mono:               ; flow into mono delay
    call    su_op_delay_do      ; when stereo delay is not enabled, we could inline this to save 5 bytes, but I expect stereo delay to be farely popular so maybe not worth the hassle
    mov     qword [rsp + 56],rcx   ; move delay workspace pointer back to stack.    
    pop     rbx      ; rbx = DelayCom, Stack: DelayVal, retaddr_su_op_delay, OperandStream, Voice, OpcodeStream, Synth, DelayWorkSpace, retaddr_su_run_vm, VoicesRemain, PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    pop     rsi      ; rsi = DelayVal, Stack: retaddr_su_op_delay, OperandStream, Voice, OpcodeStream, Synth, DelayWorkSpace, retaddr_su_run_vm, VoicesRemain, PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    ret

;-------------------------------------------------------------------------------
;   su_op_delay_do: executes the actual delay
;-------------------------------------------------------------------------------
;   Pseudocode:
;   q = dr*x
;   for (i = 0;i < count;i++)
;     s = b[(t-delaytime[i+offset])&65535]
;     q += s
;     o[i] = o[i]*da+s*(1-da)
;     b[t] = f*o[i] +p^2*x
;  Perform dc-filtering q and output q
;-------------------------------------------------------------------------------
section .su_op_delay_do code align=1
su_op_delay_do:                         ; x y
    fld     st0
    fmul    dword [rdx]  ; p*x y
    fmul    dword [rdx]  ; p*p*x y
    fxch                                        ; y p*p*x
    fmul    dword [rdx + 4]      ; dr*y p*p*x
su_op_delay_loop:
        mov     edi, esi
        sub     di, word [rbx]                      ; we perform the math in 16-bit to wrap around
        fld     dword [rcx+su_delayline_wrk.buffer+rdi*4]; s dr*y p*p*x, where s is the sample from delay buffer
        fadd    st1, st0                                ; s dr*y+s p*p*x (add comb output to current output)
        fld1                                            ; 1 s dr*y+s p*p*x
        fsub    dword [rdx + 12]         ; 1-da s dr*y+s p*p*x
        fmulp   st1, st0                                ; s*(1-da) dr*y+s p*p*x
        fld     dword [rdx + 12]         ; da s*(1-da) dr*y+s p*p*x
        fmul    dword [rcx+su_delayline_wrk.filtstate]  ; o*da s*(1-da) dr*y+s p*p*x, where o is stored
        faddp   st1, st0                                ; o*da+s*(1-da) dr*y+s p*p*x    
    lea     r9, [rel FCONST_0_500000]
        fadd    dword [r9]           ; add and sub small offset to prevent denormalization. WARNING: this is highly important, as the damp filters might denormalize and give 100x CPU penalty
        fsub    dword [r9]           ; See for example: https://stackoverflow.com/questions/36781881/why-denormalized-floats-are-so-much-slower-than-other-floats-from-hardware-arch
        fst     dword [rcx+su_delayline_wrk.filtstate]  ; o'=o*da+s*(1-da), o' dr*y+s p*p*x
        fmul    dword [rdx + 8]     ; f*o' dr*y+s p*p*x
        fadd    st0, st2                                ; f*o'+p*p*x dr*y+s p*p*x
        fstp    dword [rcx+su_delayline_wrk.buffer+rsi*4]; save f*o'+p*p*x to delay buffer
        add     rbx,2                                   ; move to next index
        add     rcx, su_delayline_wrk.size              ; go to next delay delay workspace
        sub     ah, 2
        jg      su_op_delay_loop                        ; if ah > 0, goto loop
    fstp    st1                                 ; dr*y+s1+s2+s3+...
    ; DC-filtering
    fld     dword [rcx+su_delayline_wrk.dcout]  ; o s    
    lea     r9, [rel FCONST_0_99609375]
    fmul    dword [r9]                ; c*o s
    fsub    dword [rcx+su_delayline_wrk.dcin]   ; c*o-i s
    fxch                                        ; s c*o-i
    fst     dword [rcx+su_delayline_wrk.dcin]   ; i'=s, s c*o-i
    faddp   st1                                 ; s+c*o-i    
    lea     r9, [rel FCONST_0_500000]
    fadd    dword [r9]          ; add and sub small offset to prevent denormalization. WARNING: this is highly important, as low pass filters might denormalize and give 100x CPU penalty
    fsub    dword [r9]          ; See for example: https://stackoverflow.com/questions/36781881/why-denormalized-floats-are-so-much-slower-than-other-floats-from-hardware-arch
    fst     dword [rcx+su_delayline_wrk.dcout]  ; o'=s+c*o-i
    ret



;-------------------------------------------------------------------------------
;   OUT opcode: outputs and pops the signal
;-------------------------------------------------------------------------------
;   Stereo: add ST0 to left out and ST1 to right out, then pop
;-------------------------------------------------------------------------------
section .su_op_out code align=1
su_op_out:   ; l r
    mov     rdi, [rsp + 32] ; DI points to the synth object, use DI consistently in sinks/sources presumably to increase compression rate
    call    su_op_out_mono
    add     rdi, 4 ; shift from left to right channel
su_op_out_mono:
    fmul    dword [rdx] ; multiply by gain
    fadd    dword [rdi + su_synthworkspace.left]   ; add current value of the output
    fstp    dword [rdi + su_synthworkspace.left]   ; store the new value of the output
    ret

;-------------------------------------------------------------------------------
;   OUTAUX opcode: outputs to main and aux1 outputs and pops the signal
;-------------------------------------------------------------------------------
;   Mono: add outgain*ST0 to main left port and auxgain*ST0 to aux1 left
;   Stereo: also add outgain*ST1 to main right port and auxgain*ST1 to aux1 right
;-------------------------------------------------------------------------------
section .su_op_outaux code align=1
su_op_outaux: ; l r
    mov     rdi, [rsp + 32]
    call    su_op_outaux_mono
    add     rdi, 4
su_op_outaux_mono:
    fld     st0                                     ; l l
    fmul    dword [rdx]   ; g*l
    fadd    dword [rdi + su_synthworkspace.left]             ; g*l+o
    fstp    dword [rdi + su_synthworkspace.left]             ; o'=g*l+o
    fmul    dword [rdx + 4]   ; h*l
    fadd    dword [rdi + su_synthworkspace.aux]              ; h*l+a
    fstp    dword [rdi + su_synthworkspace.aux]              ; a'=h*l+a
    ret

;-------------------------------------------------------------------------------
;   SEND opcode: adds the signal to a port
;-------------------------------------------------------------------------------
;   Mono: adds signal to a memory address, defined by a word in VAL stream
;   Stereo: also add right signal to the following address
;-------------------------------------------------------------------------------
section .su_op_send code align=1
su_op_send:
    lodsw
    mov     rcx, [rsp + 16]  ; load pointer to voice
    pushf   ; uh ugly: we save the flags just for the stereo carry bit. Doing the .CX loading later crashed the synth for stereo sends as loading the synth address from stack was f'd up by the "call su_op_send_mono"
    test    ah, 0x80
    jz      su_op_send_skipglobal
    mov     rcx, [rsp + 32 + 8]
su_op_send_skipglobal:
    popf
    jnc     su_op_send_mono
    mov     rdi, rax
    inc     rax  ; send the right channel first
    fxch                        ; r l
    call    su_op_send_mono     ; (r) l
    mov     rax, rdi            ; move back to original address
    test    al, 0x8             ; if r was not popped and is still in the stack
    jnz     su_op_send_mono
    fxch                        ; swap them back: l r
su_op_send_mono:
    test    al, 0x8             ; if the SEND_POP bit is not set
    jnz     su_op_send_skippush
    fld     st0                 ; duplicate the signal on stack: s s
su_op_send_skippush:            ; there is signal s, but maybe also another: s (s)
    fld     dword [rdx]   ; a l (l)    
    lea     r9, [rel FCONST_0_500000]
    fsub    dword [r9]                    ; a-.5 l (l)
    fadd    st0                                ; g=2*a-1 l (l)
    and     ah, 0x7f ; eax = send address, clear the global bit
    or      al, 0x8 ; set the POP bit always, at the same time shifting to ports instead of wrk
    fmulp   st1, st0                           ; g*l (l)
    fadd    dword [rcx + rax*4]     ; g*l+L (l),where L is the current value
    fstp    dword [rcx + rax*4]     ; (l)
    ret

;-------------------------------------------------------------------------------
;   ENVELOPE opcode: pushes an ADSR envelope value on stack [0,1]
;-------------------------------------------------------------------------------
;   Mono:   push the envelope value on stack
;   Stereo: push the envelope valeu on stack twice
;-------------------------------------------------------------------------------
section .su_op_envelope code align=1
su_op_envelope:
    jnc     su_op_envelope_mono
    call    su_op_envelope_mono
    fld     st0
    ret
su_op_envelope_mono:
    mov     eax, dword [rdx-su_voice.inputs+su_voice.sustain] ; eax = su_instrument.sustain
    test    eax, eax                            ; if (eax != 0)
    jne     su_op_envelope_process              ;   goto process
    mov     al, 3  ; [state]=RELEASE
    mov     dword [rbp], eax               ; note that mov al, XXX; mov ..., eax is less bytes than doing it directly
su_op_envelope_process:
    mov     eax, dword [rbp]  ; al=[state]
    fld     dword [rbp+4]       ; x=[level]
    cmp     al, 2               ; if (al==SUSTAIN)
    je      short su_op_envelope_leave2         ;   goto leave2
su_op_envelope_attac:
    cmp     al, 0                 ; if (al!=ATTAC)
    jne     short su_op_envelope_decay          ;   goto decay
    call    su_nonlinear_map                ; a x, where a=attack
    faddp   st1, st0                            ; a+x
    fld1                                        ; 1 a+x
    fucomi  st1                                 ; if (a+x<=1) // is attack complete?
    fcmovnb st0, st1                            ;   a+x a+x
    jbe     short su_op_envelope_statechange    ; else goto statechange
su_op_envelope_decay:
    cmp     al, 1                 ; if (al!=DECAY)
    jne     short su_op_envelope_release        ;   goto release
    call    su_nonlinear_map                ; d x, where d=decay
    fsubp   st1, st0                            ; x-d
    fld     dword [rdx + 8]    ; s x-d, where s=sustain
    fucomi  st1                                 ; if (x-d>s) // is decay complete?
    fcmovb  st0, st1                            ;   x-d x-d
    jnc     short su_op_envelope_statechange    ; else goto statechange
su_op_envelope_release:
    cmp     al, 3               ; if (al!=RELEASE)
    jne     short su_op_envelope_leave          ;   goto leave
    call    su_nonlinear_map                ; r x, where r=release
    fsubp   st1, st0                            ; x-r
    fldz                                        ; 0 x-r
    fucomi  st1                                 ; if (x-r>0) // is release complete?
    fcmovb  st0, st1                            ;   x-r x-r, then goto leave
    jc      short su_op_envelope_leave
su_op_envelope_statechange:
    inc     dword [rbp]       ; [state]++
su_op_envelope_leave:
    fstp    st1                                 ; x', where x' is the new value
    fst     dword [rbp+4]       ; [level]=x'
su_op_envelope_leave2:
    fmul    dword [rdx + 16]       ; [gain]*x'
    ret

;-------------------------------------------------------------------------------
;   NOISE opcode: creates noise
;-------------------------------------------------------------------------------
;   Mono:   push a random value [-1,1] value on stack
;   Stereo: push two (differeent) random values on stack
;-------------------------------------------------------------------------------
section .su_op_noise code align=1
su_op_noise:
    lea     rcx,[rsp + 96]
    imul    eax, [rcx],16007
    mov     [rcx],eax
    fild    dword [rcx]
lea     r9, [rel ICONST_2147483648]
    fidiv   dword [r9] ; 65536*32768
    fld     dword [rdx]
    call    su_waveshaper
    fmul    dword [rdx + 4]
    ret

;-------------------------------------------------------------------------------
;   OSCILLAT opcode: oscillator, the heart of the synth
;-------------------------------------------------------------------------------
;   Mono:   push oscillator value on stack
;   Stereo: push l r on stack, where l has opposite detune compared to r
;-------------------------------------------------------------------------------
section .su_op_oscillator code align=1
su_op_oscillator:
    push    0
    pop     rcx     ; clear cx without affecting flags
    xchg    ecx, dword [rbp + 56]
    lodsb                                   ; load the flags
    fld     dword [rdx + 4] ; e, where e is the detune [0,1]
lea     r9, [rel FCONST_0_500000]
    fsub    dword [r9]                 ; e-.5
    fadd    st0, st0                        ; d=2*e-.5, where d is the detune [-1,1]
    jnc     su_op_oscillat_mono
    fld     st0                             ; d d
    add     rbp, 4                     ; move wrk...
    call    su_op_oscillat_mono             ; r d
    sub     rbp, 4                     ; ...restore wrk
    fxch                                    ; d r
    fchs                                    ; -d r, negate the detune for second round
su_op_oscillat_mono:
    
push    rax		; Stack: , retaddr_su_op_oscillator, OperandStream, Voice, OpcodeStream, Synth, DelayWorkSpace, retaddr_su_run_vm, VoicesRemain, PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
push    rbp		; Stack: OscWRK, , retaddr_su_op_oscillator, OperandStream, Voice, OpcodeStream, Synth, DelayWorkSpace, retaddr_su_run_vm, VoicesRemain, PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
push    rax		; Stack: OscFlags, OscWRK, , retaddr_su_op_oscillator, OperandStream, Voice, OpcodeStream, Synth, DelayWorkSpace, retaddr_su_run_vm, VoicesRemain, PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    fldz                            ; 0 d
    fxch                            ; d a=0, "accumulated signal"
su_op_oscillat_unison_loop:
    fst     dword [rsp]             ; save the current detune, d. We could keep it in fpu stack but it was getting big.
    call    su_op_oscillat_single   ; s a
    faddp   st1, st0                ; a+=s
    test    al, 3
    je      su_op_oscillat_unison_out
    add     rbp, 8   ; this is ok after all, as there's a pop in the end of unison loop
    fld     dword [rdx + 8] ; p s

lea     r9, [rel ICONST_1034594986]
    fadd    dword [r9]  ; 1/12 p s, add some little phase offset to unison oscillators so they don't start in sync
    fstp    dword [rdx + 8] ; s    note that this changes the phase for second, possible stereo run. That's probably ok
    fld     dword [rsp]             ; d s

lea     r9, [rel FCONST_0_500000]
    fmul    dword [r9]         ; .5*d s    // negate and halve the detune of each oscillator
    fchs                            ; -.5*d s   // negate and halve the detune of each oscillator
    dec     eax
    jmp     short su_op_oscillat_unison_loop
su_op_oscillat_unison_out:
    
pop     rax      ; rax = OscFlags, Stack: OscWRK, , retaddr_su_op_oscillator, OperandStream, Voice, OpcodeStream, Synth, DelayWorkSpace, retaddr_su_run_vm, VoicesRemain, PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
pop     rbp      ; rbp = OscWRK, Stack: , retaddr_su_op_oscillator, OperandStream, Voice, OpcodeStream, Synth, DelayWorkSpace, retaddr_su_run_vm, VoicesRemain, PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
pop     rax      ; rax = , Stack: retaddr_su_op_oscillator, OperandStream, Voice, OpcodeStream, Synth, DelayWorkSpace, retaddr_su_run_vm, VoicesRemain, PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    ret
su_op_oscillat_single:
    fld     dword [rdx]
lea     r9, [rel FCONST_0_500000]
    fsub    dword [r9]
lea     r9, [rel FCONST_0_00781250]
    fdiv    dword [r9]
    faddp   st1
    test    al, byte 0x08
    jnz     su_op_oscillat_skipnote
    fiadd   dword [rdx-su_voice.inputs+su_voice.note]   ; // st0 is note, st1 is t+d offset
su_op_oscillat_skipnote:
lea     r9, [rel ICONST_1034594986]
    fmul    dword [r9]
    call    su_power
    test    al, byte 0x08
    jz      short su_op_oscillat_normalize_note
lea     r9, [rel FCONST_3_80000em05]
    fmul    dword [r9]  ; // st0 is now frequency for lfo
    jmp     short su_op_oscillat_normalized
su_op_oscillat_normalize_note:
lea     r9, [rel FCONST_9_269614em05]
    fmul    dword [r9]   ; // st0 is now frequency
su_op_oscillat_normalized:
    fadd    dword [rbp]
    push    rcx
    fadd    dword [rsp]
    pop     rcx
    test    al, byte 0x80
    jz      short su_op_oscillat_not_sample
    fst     dword [rbp]  ; for samples, we store the phase without mod(p,1)
    fadd    dword [rdx + 8]
    call    su_oscillat_sample
    jmp     su_op_oscillat_shaping ; skip the rest to avoid color phase normalization and colorloading
su_op_oscillat_not_sample:
    fld1                     ; we need to take mod(p,1) so the frequency does not drift as the float
    fadd    st1, st0         ; make no mistake: without this, there is audible drifts in oscillator pitch
    fxch                     ; as the actual period changes once the phase becomes too big
    fprem                    ; we actually computed mod(p+1,1) instead of mod(p,1) as the fprem takes mod
    fstp    st1              ; towards zero
    fst     dword [rbp] ; store back the updated phase
    fadd    dword [rdx + 8]
    fld1                    ; this is a bit stupid, but we need to take mod(x,1) again after phase modulations
    fadd    st1, st0        ; as the actual oscillator functions expect x in [0,1]
    fxch
    fprem
    fstp    st1
    fld     dword [rdx + 12]               ; // c      p
    ; every oscillator test included if needed
    test    al, byte 0x40
    jz      short su_op_oscillat_notsine
    call    su_oscillat_sine
su_op_oscillat_notsine:
    test    al, byte 0x20
    jz      short su_op_oscillat_not_trisaw
    call    su_oscillat_trisaw
su_op_oscillat_not_trisaw:
    test    al, byte 0x10
    jz      short su_op_oscillat_not_pulse
    call    su_oscillat_pulse
su_op_oscillat_not_pulse:
su_op_oscillat_shaping:
    ; finally, shape the oscillator and apply gain
    fld     dword [rdx + 16]
    call    su_waveshaper
su_op_oscillat_gain:
    fmul    dword [rdx + 20]
    ret

section .su_oscillat_pulse code align=1
su_oscillat_pulse:
    fucomi  st1                             ; // c      p
    fld1
    jnc     short su_oscillat_pulse_up      ; // +1     c       p
    fchs                                    ; // -1     c       p
su_oscillat_pulse_up:
    fstp    st1                             ; // +-1    p
    fstp    st1                             ; // +-1
    ret

section .su_oscillat_trisaw code align=1
su_oscillat_trisaw:
    fucomi  st1                             ; // c      p
    ; we do jnbe instead of jnc to avoid NaN. phase cannot be < 0 or >= 1, so the important cases are
    ; c = 0 => the branch is never taken, because c > p can never happen, and thus results in .../(1-c)    
    ; c = 1 => the branch is always taken, because p < c and thus always gives .../c
    jnbe    short su_oscillat_trisaw_up     
    fld1                                    ; // 1      c       p
    fsubr   st2, st0                        ; // 1      c       1-p
    fsubrp  st1, st0                        ; // 1-c    1-p
su_oscillat_trisaw_up:
    fdivp   st1, st0                        ; // tp'/tc
    fadd    st0                             ; // 2*''
    fld1                                    ; // 1      2*''
    fsubp   st1, st0                        ; // 2*''-1
    ret

section .su_oscillat_sine code align=1
su_oscillat_sine:
    fucomi  st1                             ; // c      p
    jnc     short su_oscillat_sine_do
    fstp    st1
    fsub    st0, st0                        ; // 0
    ret
su_oscillat_sine_do:
    fdivp   st1, st0                        ; // p/c
    fldpi                                   ; // pi     p
    fadd    st0                             ; // 2*pi   p
    fmulp   st1, st0                        ; // 2*pi*p
    fsin                                    ; // sin(2*pi*p)
    ret

section .su_oscillat_sample code align=1
su_oscillat_sample:    
    push    rax		; Stack: SampleAx, retaddr_su_oscillat_sample, retaddr_su_op_oscillator, OperandStream, Voice, OpcodeStream, Synth, DelayWorkSpace, retaddr_su_run_vm, VoicesRemain, PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    push    rdx		; Stack: SampleDx, SampleAx, retaddr_su_oscillat_sample, retaddr_su_op_oscillator, OperandStream, Voice, OpcodeStream, Synth, DelayWorkSpace, retaddr_su_run_vm, VoicesRemain, PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    push    rcx		; Stack: SampleCx, SampleDx, SampleAx, retaddr_su_oscillat_sample, retaddr_su_op_oscillator, OperandStream, Voice, OpcodeStream, Synth, DelayWorkSpace, retaddr_su_run_vm, VoicesRemain, PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    push    rbx		; Stack: SampleBx, SampleCx, SampleDx, SampleAx, retaddr_su_oscillat_sample, retaddr_su_op_oscillator, OperandStream, Voice, OpcodeStream, Synth, DelayWorkSpace, retaddr_su_run_vm, VoicesRemain, PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    push    rdi		; Stack: SampleDi, SampleBx, SampleCx, SampleDx, SampleAx, retaddr_su_oscillat_sample, retaddr_su_op_oscillator, OperandStream, Voice, OpcodeStream, Synth, DelayWorkSpace, retaddr_su_run_vm, VoicesRemain, PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song                               ; edx must be saved, eax & ecx if this is stereo osc
    push    rax
    mov     al, byte [rsi-4]                                ; reuse "color" as the sample number    
    lea     r9, [rel su_sample_offsets]
    lea     rdi, [r9 + rax*8]; edi points now to the sample table entry    
    lea     r9, [rel FCONST_84_28075]
    fmul    dword [r9]                  ; p*r
    fistp   dword [rsp]
    pop     rdx                                             ; edx is now the sample number
    movzx   ebx, word [rdi + 4]    ; ecx = loopstart
    sub     edx, ebx                                        ; if sample number < loop start
    jb      su_oscillat_sample_not_looping                  ;   then we're not looping yet
    mov     eax, edx                                        ; eax = sample number
    movzx   ecx, word [rdi + 6]   ; edi is now the loop length
    xor     edx, edx                                        ; div wants edx to be empty
    div     ecx                                             ; edx is now the remainder
su_oscillat_sample_not_looping:
    add     edx, ebx                                        ; sampleno += loopstart
    add     edx, dword [rdi]    
    lea     r9, [rel su_sample_table]
    fild    word [r9 + rdx*2]    
    lea     r9, [rel FCONST_32767_0]
    fdiv    dword [r9]    
    pop     rdi      ; rdi = SampleDi, Stack: SampleBx, SampleCx, SampleDx, SampleAx, retaddr_su_oscillat_sample, retaddr_su_op_oscillator, OperandStream, Voice, OpcodeStream, Synth, DelayWorkSpace, retaddr_su_run_vm, VoicesRemain, PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    pop     rbx      ; rbx = SampleBx, Stack: SampleCx, SampleDx, SampleAx, retaddr_su_oscillat_sample, retaddr_su_op_oscillator, OperandStream, Voice, OpcodeStream, Synth, DelayWorkSpace, retaddr_su_run_vm, VoicesRemain, PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    pop     rcx      ; rcx = SampleCx, Stack: SampleDx, SampleAx, retaddr_su_oscillat_sample, retaddr_su_op_oscillator, OperandStream, Voice, OpcodeStream, Synth, DelayWorkSpace, retaddr_su_run_vm, VoicesRemain, PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    pop     rdx      ; rdx = SampleDx, Stack: SampleAx, retaddr_su_oscillat_sample, retaddr_su_op_oscillator, OperandStream, Voice, OpcodeStream, Synth, DelayWorkSpace, retaddr_su_run_vm, VoicesRemain, PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    pop     rax      ; rax = SampleAx, Stack: retaddr_su_oscillat_sample, retaddr_su_op_oscillator, OperandStream, Voice, OpcodeStream, Synth, DelayWorkSpace, retaddr_su_run_vm, VoicesRemain, PolyphonyBitmask, Sample, Row, GlobalTick, RandSeed, VoiceTrackBitmask, NonVolatileRbp, NonVolatileRbx, NonVolatile, NonVolatileRsi, OutputBufPtr, retaddr_su_render_song 
    ret

;-------------------------------------------------------------------------------
;   IN opcode: inputs and clears a global port
;-------------------------------------------------------------------------------
;   Mono: push the left channel of a global port (out or aux)
;   Stereo: also push the right channel (stack in l r order)
;-------------------------------------------------------------------------------
section .su_op_in code align=1
su_op_in:
    lodsb
    mov     rdi, [rsp + 32]
    xor     ecx, ecx ; we cannot xor before jnc, so we have to do it mono & stereo. LAHF / SAHF could do it, but is the same number of bytes with more entropy
    fld     dword [rdi + su_synthworkspace.right + rax*4]
    mov     dword [rdi + su_synthworkspace.right + rax*4], ecx
    fld     dword [rdi + su_synthworkspace.left + rax*4]
    mov     dword [rdi + su_synthworkspace.left + rax*4], ecx
    ret


section .su_load_gmdls code align=1
global su_load_gmdls
su_load_gmdls:
    extern OpenFile ; requires windows
    extern ReadFile ; requires windows
    ;        Win64 ABI: RCX, RDX, R8, and R9
    sub     rsp, 40         ; Win64 ABI requires "shadow space" + space for one parameter.
    mov     rdx, qword su_sample_table
    mov     rcx, qword su_gmdls_path1
    xor     r8,r8 ; OF_READ
    push    rdx                 ; &ofstruct, blatantly reuse the sample table
    push    rcx
    call    OpenFile            ; eax = OpenFile(path,&ofstruct,OF_READ)
    pop     rcx
    pop     rdx
    movsxd  rcx, eax
    mov     qword [rsp+32], 0
    mov     r9, rdx
    mov     r8d, 3440660   ; number of bytes to read
    call    ReadFile                ; Readfile(handle,&su_sample_table,SAMPLE_TABLE_SIZE,&bytes_read,NULL)
    add     rsp, 40         ; shadow space, as required by Win64 ABI
    ret


section .su_gmdls_path1 data align=1
su_gmdls_path1:
    db 'drivers/gm.dls',0


section .susamtable bss align=256
su_sample_table:
    resb    3440660    ; size of gmdls.


;-------------------------------------------------------------------------------
;   su_nonlinear_map function: returns 2^(-24*x) of parameter number _AX
;-------------------------------------------------------------------------------
;   Input:      _AX     :   parameter number (e.g. for envelope: 0 = attac, 1 = decay...)
;               INP     :   pointer to transformed operands
;   Output:     st0     :   2^(-24*x), where x is the parameter in the range 0-1
;-------------------------------------------------------------------------------
section .su_nonlinear_map code align=1
su_nonlinear_map:
    fld     dword [rdx+rax*4]   ; x, where x is the parameter in the range 0-1
    
lea     r9, [rel ICONST_24]
    fimul   dword [r9]      ; 24*x
    fchs                        ; -24*x


;-------------------------------------------------------------------------------
;   su_power function: computes 2^x
;-------------------------------------------------------------------------------
;   Input:      st0     :   x
;   Output:     st0     :   2^x
;-------------------------------------------------------------------------------
global su_pow
su_pow:
su_power:
    fld1          ; 1 x
    fld st1       ; x 1 x
    fprem         ; mod(x,1) 1 x
    f2xm1         ; 2^mod(x,1)-1 1 x
    faddp st1,st0 ; 2^mod(x,1) x
    fscale        ; 2^mod(x,1)*2^trunc(x) x
                  ; Equal to:
                  ; 2^x x
    fstp st1      ; 2^x
    ret


;-------------------------------------------------------------------------------
;   DISTORT opcode: apply distortion on the signal
;-------------------------------------------------------------------------------
;   Mono:   x   ->  x*a/(1-a+(2*a-1)*abs(x))            where x is clamped first
;   Stereo: l r ->  l*a/(1-a+(2*a-1)*abs(l)) r*a/(1-a+(2*a-1)*abs(r))
;   This is placed here to be able to flow into waveshaper & also include
;   wave shaper if needed by some other function; need to investigate the
;   best way to do this
;-------------------------------------------------------------------------------
section .su_op_distort code align=1
su_op_distort:call    su_effects_stereohelper
    fld     dword [rdx]

su_waveshaper:
    fld     st0                             ; a a x
    
lea     r9, [rel FCONST_0_500000]
    fsub    dword [r9]                 ; a-.5 a x
    fadd    st0                             ; 2*a-1 a x
    fld     st2                             ; x 2*a-1 a x
    fabs                                    ; abs(x) 2*a-1 a x
    fmulp   st1                             ; (2*a-1)*abs(x) a x
    fld1                                    ; 1 (2*a-1)*abs(x) a x
    faddp   st1                             ; 1+(2*a-1)*abs(x) a x
    fsub    st1                             ; 1-a+(2*a-1)*abs(x) a x
    fdivp   st1, st0                        ; a/(1-a+(2*a-1)*abs(x)) x
    fmulp   st1                             ; x*a/(1-a+(2*a-1)*abs(x))
    ret

;-------------------------------------------------------------------------------
;   su_effects_stereohelper: moves the workspace to next, does the filtering for
;   right channel (pulling the calling address from stack), rewinds the
;   workspace and returns
;-------------------------------------------------------------------------------
section .su_effects_stereohelper code align=1
su_effects_stereohelper:
    jnc     su_effects_stereohelper_mono ; carry is still the stereo bit
    add     rbp, 16
    fxch                  ; r l
    call    [rsp]         ; call whoever called me...
    fxch                  ; l r
    sub     rbp, 16       ; move WRK back to where it was
su_effects_stereohelper_mono:
    ret                   ; return to process l/mono sound



;-------------------------------------------------------------------------------
; The opcode table jump table. This is constructed to only include the opcodes
; that are used so that the jump table is as small as possible.
;-------------------------------------------------------------------------------
section .su_vm_jumptable data align=1
su_vm_jumptable:
    dq    su_op_envelope
    dq    su_op_oscillator
    dq    su_op_mulp
    dq    su_op_filter
    dq    su_op_pan
    dq    su_op_hold
    dq    su_op_outaux
    dq    su_op_loadnote
    dq    su_op_send
    dq    su_op_addp
    dq    su_op_in
    dq    su_op_delay
    dq    su_op_noise
    dq    su_op_belleq
    dq    su_op_distort
    dq    su_op_invgain
    dq    su_op_out

;-------------------------------------------------------------------------------
; The number of transformed parameters each opcode takes
;-------------------------------------------------------------------------------
section .su_vm_transformcounts data align=1
su_vm_transformcounts:
    db    5
    db    6
    db    0
    db    2
    db    1
    db    1
    db    2
    db    0
    db    1
    db    0
    db    0
    db    4
    db    2
    db    3
    db    1
    db    1
    db    1


;-------------------------------------------------------------------------------
;    Patterns
;-------------------------------------------------------------------------------
section .su_patterns data align=1
su_patterns:
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,94,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,70,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,70,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0
    db 73,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,73,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,66,1,1,1,1,1,1,1,1,1,1,1
    db 1,1,1,1,1,1,66,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,71,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,71,1,1,1,1,1
    db 0,0,0,0,0,0,87,1,1,1,1,1,0,0,0,0,0,0,87,1,1,0,0,0,87,1,1,1,1,1,1,1,1,1,1,1,85,1,1,1,1,1,1,1,1,1,1,1
    db 87,1,1,1,1,1,1,1,1,1,1,1,88,1,1,0,0,0,0,0,0,0,0,0,87,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,87,1,1,0,0,0
    db 87,1,1,1,1,1,1,1,1,1,1,1,88,1,1,0,0,0,0,0,0,0,0,0,87,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0
    db 87,1,1,1,1,1,0,0,0,0,0,0,88,1,1,1,1,1,0,0,0,0,0,0,87,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0
    db 70,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,70,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,70,1,1,1,1,1,1,1,1,1,1,1
    db 0,0,93,1,93,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,75,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,75,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0
    db 78,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,78,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,71,1,1,1,1,1,1,1,1,1,1,1
    db 1,1,1,1,1,1,71,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,76,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,76,1,1,1,1,1
    db 0,0,0,0,0,0,83,1,1,1,1,1,0,0,0,0,0,0,83,1,1,0,0,0,83,1,1,1,1,1,1,1,1,1,1,1,82,1,1,1,1,1,1,1,1,1,1,1
    db 83,1,1,1,1,1,1,1,1,1,1,1,85,1,1,0,0,0,0,0,0,0,0,0,83,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,83,1,1,0,0,0
    db 83,1,1,1,1,1,1,1,1,1,1,1,85,1,1,0,0,0,0,0,0,0,0,0,83,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0
    db 83,1,1,1,1,1,0,0,0,0,0,0,85,1,1,1,1,1,0,0,0,0,0,0,83,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0
    db 75,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,75,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,75,1,1,1,1,1,1,1,1,1,1,1
    db 0,91,1,1,1,91,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,79,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,79,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0
    db 82,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,82,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,75,1,1,1,1,1,1,1,1,1,1,1
    db 1,1,1,1,1,1,75,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,80,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,80,1,1,1,1,1
    db 0,0,0,0,0,0,80,1,1,1,1,1,0,0,0,0,0,0,80,1,1,0,0,0,80,1,1,1,1,1,1,1,1,1,1,1,78,1,1,1,1,1,1,1,1,1,1,1
    db 80,1,1,1,1,1,1,1,1,1,1,1,81,1,1,0,0,0,0,0,0,0,0,0,80,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,80,1,1,0,0,0
    db 80,1,1,1,1,1,1,1,1,1,1,1,81,1,1,0,0,0,0,0,0,0,0,0,80,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0
    db 80,1,1,1,1,1,0,0,0,0,0,0,81,1,1,1,1,1,0,0,0,0,0,0,80,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0
    db 79,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,79,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,79,1,1,1,1,1,1,1,1,1,1,1
    db 88,1,1,1,1,1,88,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,80,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,80,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0
    db 83,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,83,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,76,1,1,1,1,1,1,1,1,1,1,1
    db 1,1,1,1,1,1,76,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,81,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,81,1,1,1,1,1
    db 0,0,0,0,0,0,78,1,1,1,1,1,0,0,0,0,0,0,78,1,1,0,0,0,78,1,1,1,1,1,1,1,1,1,1,1,77,1,1,1,1,1,1,1,1,1,1,1
    db 78,1,1,1,1,1,1,1,1,1,1,1,80,1,1,0,0,0,0,0,0,0,0,0,78,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,78,1,1,0,0,0
    db 78,1,1,1,1,1,1,1,1,1,1,1,80,1,1,0,0,0,0,0,0,0,0,0,78,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0
    db 78,1,1,1,1,1,0,0,0,0,0,0,80,1,1,1,1,1,0,0,0,0,0,0,78,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0
    db 80,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,80,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,80,1,1,1,1,1,1,1,1,1,1,1
    db 0,0,0,0,0,0,0,0,0,0,0,0,82,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,82,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0
    db 85,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,85,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,78,1,1,1,1,1,1,1,1,1,1,1
    db 1,1,1,1,1,1,78,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,83,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,83,1,1,1,1,1
    db 0,0,0,0,0,0,75,1,1,1,1,1,0,0,0,0,0,0,75,1,1,0,0,0,75,1,1,1,1,1,1,1,1,1,1,1,73,1,1,1,1,1,1,1,1,1,1,1
    db 75,1,1,1,1,1,1,1,1,1,1,1,76,1,1,0,0,0,0,0,0,0,0,0,75,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,75,1,1,0,0,0
    db 75,1,1,1,1,1,1,1,1,1,1,1,76,1,1,0,0,0,0,0,0,0,0,0,75,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0
    db 75,1,1,1,1,1,0,0,0,0,0,0,76,1,1,1,1,1,0,0,0,0,0,0,75,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0
    db 82,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,82,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,82,1,1,1,1,1,1,1,1,1,1,1
    db 0,0,0,0,0,0,0,0,0,0,0,0,87,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,87,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0
    db 90,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,90,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,83,1,1,1,1,1,1,1,1,1,1,1
    db 1,0,0,0,0,0,83,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,88,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,88,1,1,1,1,1
    db 0,0,0,0,0,0,71,1,1,1,1,1,0,0,0,0,0,0,71,1,1,0,0,0,71,1,1,1,1,1,1,1,1,1,1,1,70,1,1,1,1,1,1,1,1,1,1,1
    db 71,1,1,1,1,1,1,1,1,1,1,1,73,1,1,0,0,0,0,0,0,0,0,0,71,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,71,1,1,0,0,0
    db 71,1,1,1,1,1,1,1,1,1,1,1,73,1,1,0,0,0,0,0,0,0,0,0,71,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0
    db 71,1,1,1,1,1,0,0,0,0,0,0,73,1,1,1,1,1,0,0,0,0,0,0,71,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0
    db 87,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,87,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,87,1,1,1,1,1,1,1,1,1,1,1
    db 72,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,24,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,21,1,1,1,1,1
    db 64,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    db 65,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    db 48,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    db 68,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    db 108,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 79,91,84,96,91,103,79,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 84,1,0,0,91,1,0,0,88,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 75,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    db 1,1,1,1,1,1,1,1,1,1,1,1,78,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,77,1,1,1,1,1,1,1,1,1,1,1
    db 73,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    db 1,1,1,1,1,1,1,1,1,1,1,1,76,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,75,1,1,1,1,1,1,1,1,1,1,1
    db 1,1,1,1,1,1,1,1,1,1,1,1,73,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,74,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    db 1,1,1,1,1,1,1,1,1,1,1,1,75,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,73,1,1,1,1,1,1,1,1,1,1,1
    db 71,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    db 1,1,1,1,1,1,1,1,1,1,1,1,73,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,72,1,1,1,1,1,1,1,1,1,1,1
    db 1,1,1,1,1,1,1,1,1,1,1,1,70,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,71,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    db 1,1,1,1,1,1,1,1,1,1,1,1,72,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,68,1,1,1,1,1,1,1,1,1,1,1
    db 70,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    db 1,1,1,1,1,1,1,1,1,1,1,1,71,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,68,1,1,1,1,1,1,1,1,1,1,1
    db 1,1,1,1,1,1,1,1,1,1,1,1,67,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,70,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    db 1,1,1,1,1,1,1,1,1,1,1,1,71,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,65,1,1,1,1,1,1,1,1,1,1,1
    db 66,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    db 1,1,1,1,1,1,1,1,1,1,1,1,69,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,70,1,1,1,1,1,1,1,1,1,1,1
    db 1,1,1,1,1,1,1,1,1,1,1,1,66,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,66,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    db 76,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    db 80,1,1,1,1,1,1,1,1,1,1,1,78,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,63,1,1,1,1,1,1,1,1,1,1,1
    db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,73,1,1,1,1,1,0,0,0,0,0,0
    db 80,1,1,1,1,1,0,0,0,0,0,0,75,1,1,1,1,1,80,1,1,1,1,1,0,0,0,0,0,0,75,1,1,1,1,1,82,1,1,1,1,1,0,0,0,0,0,0
    db 84,1,1,1,1,1,1,1,1,1,1,1,82,1,1,1,1,1,0,0,0,0,0,0,80,1,1,1,1,1,0,0,0,0,0,0,82,1,1,1,1,1,80,1,1,1,1,1
    db 80,1,1,1,1,1,1,1,1,1,1,1,79,1,1,1,1,1,1,1,1,1,1,1,80,1,1,1,1,1,1,1,1,1,1,1,79,1,1,1,1,1,1,1,1,1,1,1
    db 77,1,1,1,1,1,1,1,1,1,1,1,75,1,1,1,1,1,0,0,0,0,0,0,73,1,1,1,1,0,0,0,0,0,0,0,75,1,1,1,1,1,77,1,1,1,1,1
    db 65,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 60,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 52,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,52,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    db 0,0,0,72,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    db 1,1,1,1,1,1,1,1,1,60,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,60,0,0,0
    db 0,84,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 1,1,1,1,1,1,1,1,1,1,1,1,60,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,60,1,1,0,0,0,0,0,0,0,0,0
    db 36,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,60,1,1,0,0,0,0,0,60,0,0,0,60,1,1,1,1,1,1,1,1,1,1,1
    db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,60,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    db 96,1,1,96,1,1,96,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,48,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 56,1,1,1,1,1,1,1,1,0,0,0,54,1,1,1,1,1,0,0,0,0,0,0,59,1,1,0,0,0,56,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 56,1,1,1,1,1,1,1,1,0,0,0,54,1,1,1,1,1,0,0,0,0,0,0,56,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0
    db 56,1,1,1,1,1,1,1,1,0,0,0,54,1,1,1,1,1,1,1,0,0,0,0,51,1,1,1,1,1,1,1,49,1,1,1,47,1,1,1,1,1,1,1,1,0,0,0
    db 0,0,0,0,0,0,56,1,1,0,0,0,0,0,0,0,0,0,51,1,0,0,0,0,54,1,1,1,1,1,56,1,1,1,1,1,0,0,0,0,0,0,59,1,1,1,1,0
    db 61,1,1,1,1,1,59,1,1,1,51,1,1,1,1,0,0,0,61,1,1,1,1,1,0,0,0,0,0,0,59,1,1,1,1,1,0,0,0,0,0,0,56,1,1,0,0,0
    db 56,1,1,1,1,1,53,1,1,1,1,1,0,0,0,0,0,0,54,1,1,1,1,1,0,0,0,0,0,0,55,1,1,1,1,1,0,0,0,0,0,0,56,1,1,1,1,1
    db 0,0,0,0,0,0,66,1,1,0,0,0,61,1,1,1,1,1,51,1,1,0,0,0,61,1,1,0,0,0,59,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    db 48,1,1,48,1,1,60,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,17,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 1,1,1,1,1,1,36,1,1,1,1,1,0,0,0,60,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,48,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    db 1,1,1,1,1,1,72,1,1,0,0,0,0,0,0,48,1,1,0,0,0,0,0,0,0,0,0,0,67,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 1,1,1,1,1,1,1,60,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,48,1,0
    db 0,0,0,48,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,72,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,48,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,48,1,1
    db 0,0,0,0,0,0,0,48,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,67,1,1,1,1,1,1,1,1,1,1,1
    db 28,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 84,72,91,79,96,84,91,79,84,72,79,67,72,60,67,55,48,36,43,31,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

;-------------------------------------------------------------------------------
;    Tracks
;-------------------------------------------------------------------------------
section .su_tracks data align=1
su_tracks:
    db 0,0,0,0,1,0,0,0,0,2,3,4,0,2,3,4,0,2,3,4,0,2,3,4,0,2,3,4,0,2,3,4,0,2,3,4,0,2,3,4,0,2,3,4,0,2,3,4,0,2,3,4,0,2,3,4,0,2,3,4,0,2,3,4,0,2,3,4,0,2,3,4,0,5,6,5,7,5,6,5,8,5,6,5,7,5,6,5,9,5,6,5,7,5,6,5,8,5,6,5,7,5,6,5,8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,10,0,0,0,0,11,12,13,0,11,12,13,0,11,12,13,0,11,12,13,0,11,12,13,0,11,12,13,0,11,12,13,0,11,12,13,0,11,12,13,0,11,12,13,0,11,12,13,0,11,12,13,0,11,12,13,0,11,12,13,0,11,12,13,0,11,12,13,0,14,15,14,16,14,15,14,17,14,15,14,16,14,15,14,18,14,15,14,16,14,15,14,17,14,15,14,16,14,15,14,17,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,19,0,0,0,0,20,21,22,0,20,21,22,0,20,21,22,0,20,21,22,0,20,21,22,0,20,21,22,0,20,21,22,0,20,21,22,0,20,21,22,0,20,21,22,0,20,21,22,0,20,21,22,0,20,21,22,0,20,21,22,0,20,21,22,0,20,21,22,0,23,24,23,25,23,24,23,26,23,24,23,25,23,24,23,27,23,24,23,25,23,24,23,26,23,24,23,25,23,24,23,26,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,28,0,0,0,0,29,30,31,0,29,30,31,0,29,30,31,0,29,30,31,0,29,30,31,0,29,30,31,0,29,30,31,0,29,30,31,0,29,30,31,0,29,30,31,0,29,30,31,0,29,30,31,0,29,30,31,0,29,30,31,0,29,30,31,0,29,30,31,0,32,33,32,34,32,33,32,35,32,33,32,34,32,33,32,36,32,33,32,34,32,33,32,35,32,33,32,34,32,33,32,35,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,37,38,39,0,37,38,39,0,37,38,39,0,37,38,39,0,37,38,39,0,37,38,39,0,37,38,39,0,37,38,39,0,37,38,39,0,37,38,39,0,37,38,39,0,37,38,39,0,37,38,39,0,37,38,39,0,37,38,39,0,37,38,39,0,40,41,40,42,40,41,40,43,40,41,40,42,40,41,40,44,40,41,40,42,40,41,40,43,40,41,40,42,40,41,40,43,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,45,46,47,0,45,46,47,0,45,46,47,0,45,46,47,0,45,46,47,0,45,46,47,0,45,46,47,0,45,46,47,0,45,46,47,0,45,46,47,0,45,46,47,0,45,46,47,0,45,46,47,0,45,46,47,0,45,46,47,0,45,46,47,0,48,49,48,50,48,49,48,51,48,49,48,50,48,49,48,52,48,49,48,50,48,49,48,51,48,49,48,50,48,49,48,51,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,53,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,55,0,0,0,0,0,0,0,56,0,0,0,0,0,0,0,55,0,0,0,0,0,0,0,55,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,57,54,54,54,54,57,54,54,54,54,54,54,54,58,54,54,54,54,54,54,54,57,54,54,54,54,54,54,54,58,54,54,54,54,54,54,54,57,54,54,54,54,54,54,54,58,54,54,54,54,54,54,54,57,54,54,54,54,54,54,54,58,54,54,54,54,54,54,54,57,54,54,54,54,54,54,54,57,54,54,54,54,54,54,54,57,54,54,54,54,54,54,54,57,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54
    db 0,0,0,0,0,0,0,0,0,57,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,59,60,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,59,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,60,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54
    db 0,0,61,62,0,0,63,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,64,65,54,54,66,67,54,68,64,65,54,54,66,67,54,68,64,65,54,54,66,67,54,68,64,65,54,54,66,67,54,68,64,65,54,54,66,67,54,68,64,65,54,54,66,67,54,68,64,65,54,54,66,67,54,68,64,65,54,54,66,67,54,68
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,66,69,54,54,70,71,54,72,66,69,54,54,70,71,54,72,66,69,54,54,70,71,54,72,66,69,54,54,70,71,54,72,66,69,54,54,70,71,54,72,66,69,54,54,70,71,54,72,66,69,54,54,70,71,54,72,66,69,54,54,70,71,54,72
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,70,73,54,54,74,75,54,76,70,73,54,54,74,75,54,76,70,73,54,54,74,75,54,76,70,73,54,54,74,75,54,76,70,73,54,54,74,75,54,76,70,73,54,54,74,75,54,76,70,73,54,54,74,75,54,76,70,73,54,54,74,75,54,76
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,60,77,54,54,78,79,54,80,60,77,54,54,81,82,83,80,60,77,54,54,78,79,54,80,60,77,54,54,81,82,83,80,60,77,54,54,78,79,54,80,60,77,54,54,81,82,83,80,60,77,54,54,78,79,54,80,60,77,54,54,81,82,83,80
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,84,85,54,0,86,87,54,0,84,85,54,0,86,87,54,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,57,54,54,54,54,54,54,54,58,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 88,0,0,0,0,0,0,89,0,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,54,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,54,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54
    db 0,0,0,0,0,0,0,91,54,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,0,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,92,0
    db 93,0,0,0,0,0,0,91,54,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,0,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,94,0
    db 0,0,0,0,0,0,0,95,96,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,96,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,96
    db 0,0,0,0,0,98,0,99,0,100,101,101,102,100,101,101,102,100,101,101,102,100,101,101,102,100,101,101,102,100,101,101,102,100,101,101,102,100,101,101,102,100,101,101,102,100,101,101,102,100,101,101,102,100,101,101,102,100,101,101,102,100,101,101,102,100,101,101,102,100,101,101,102,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,100,101,101,102,100,101,101,101,100,101,101,102,100,101,101,101,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,103,104,103,105,103,104,103,106,103,104,103,105,103,104,103,103,103,104,103,105,103,104,103,106,103,104,103,105,103,104,103,103
    db 0,0,0,0,0,107,0,108,0,109,110,110,111,109,110,110,111,109,110,110,111,109,110,110,111,109,110,110,111,109,110,110,111,109,110,110,111,109,110,110,111,109,110,110,111,109,110,110,111,109,110,110,111,109,110,110,111,109,110,110,111,109,110,110,111,109,110,110,111,109,110,110,111,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,109,110,110,111,109,110,110,110,109,110,110,111,109,110,110,110,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,112,113,112,114,112,113,112,115,112,113,112,114,112,113,112,112,112,113,112,114,112,113,112,115,112,113,112,114,112,113,112,112
    db 0,0,0,0,0,116,0,0,0,57,54,54,54,54,54,54,54,58,54,54,54,54,54,54,54,57,54,54,54,54,54,54,54,58,54,54,54,54,54,54,54,57,54,54,54,54,54,54,54,58,54,54,54,54,54,54,54,57,54,54,54,54,54,54,54,58,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,57,54,54,54,54,54,54,54,57,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54,54
    db 0,117,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
;-------------------------------------------------------------------------------
;    Sample offsets
;-------------------------------------------------------------------------------
section .su_sample_offsets data align=1
su_sample_offsets:
    dd 972709
    dw 8309
    dw 1487
    dd 641780
    dw 2423
    dw 1

;-------------------------------------------------------------------------------
;    Delay times
;-------------------------------------------------------------------------------
section .su_delay_times data align=1
su_delay_times:
    dw 1116,1188,1276,1356,1422,1492,1556,1618,1140,1212,1300,1380,1446,1516,1580,1642


;-------------------------------------------------------------------------------
;    The code for this patch, basically indices to vm jump table
;-------------------------------------------------------------------------------
section .su_patch_opcodes data align=1
su_patch_opcodes:
    db 3,5,7,9,11,12,15,0,16,2,6,18,18,18,18,18,18,0,16,18,18,18,18,18,18,0,17,19,19,19,19,19,19,0,5,19,2,18,4,6,8,10,15,0,4,4,20,2,2,6,6,16,18,8,8,10,15,0,16,18,18,0,23,25,15,0,2,18,18,2,2,6,18,2,18,4,6,2,26,8,8,6,20,8,8,10,28,31,15,0,2,2,6,26,6,8,8,10,15,0,2,2,20,26,6,26,12,18,8,8,10,15,0,2,4,6,10,15,0,4,4,20,2,6,10,15,0,16,2,6,18,18,18,18,0,16,18,18,18,18,0,4,4,20,2,6,10,15,0,23,33,35,0

;-------------------------------------------------------------------------------
;    The parameters / inputs to each opcode
;-------------------------------------------------------------------------------
section .su_patch_operands data align=1
su_patch_operands:
    db 0,79,33,3,96,68,63,0,0,64,96,128,25,91,16,64,91,74,14,75,0,0,0,2,128,54,128,128,54,132,128,54,136,128,54,140,128,54,144,128,62,148,96,48,128,96,48,132,96,48,136,96,48,140,96,48,144,96,56,148,96,129,128,96,129,132,96,129,136,96,129,140,96,129,144,96,137,148,64,64,64,64,43,70,64,90,90,0,23,84,58,64,124,87,112,0,64,64,92,128,64,64,64,38,96,64,64,128,40,76,56,0,65,42,64,33,88,54,0,64,48,64,33,19,88,80,0,128,35,75,63,0,127,89,168,0,49,128,36,91,128,68,60,56,26,96,32,184,96,56,184,2,24,0,124,43,0,15,64,64,0,69,0,47,128,0,128,212,0,136,216,72,78,0,0,128,50,80,0,0,64,0,168,0,53,68,0,0,98,26,247,255,79,64,0,128,64,64,67,0,46,0,0,128,128,85,91,128,32,83,128,96,86,63,100,15,84,100,64,19,128,58,74,76,4,0,61,0,0,100,28,60,0,0,64,43,64,85,128,12,97,64,72,64,110,6,12,64,0,0,64,0,64,0,0,65,25,64,64,9,0,39,152,0,96,64,16,104,64,64,64,128,6,0,128,0,0,96,75,64,0,1,76,96,128,64,128,8,52,64,0,64,64,64,16,64,64,0,64,64,64,16,0,128,0,0,128,64,128,0,75,0,0,0,2,128,54,212,128,54,216,128,38,212,128,46,216,96,32,212,96,32,216,96,48,212,96,56,216,52,64,0,64,64,64,24,64,64,0,64,64,64,16,0,128,0,0,75,64,97,89,2,64,128

;-------------------------------------------------------------------------------
;    Constants
;-------------------------------------------------------------------------------
section .constants data align=1
FCONST_0_00781250       dd 0x3c000000
FCONST_0_500000         dd 0x3f000000
FCONST_6_643856         dd 0x40d49a78
FCONST_0_99609375       dd 0x3f7f0000
FCONST_3_80000em05      dd 0x381f6230
FCONST_9_269614em05     dd 0x38c265dc
FCONST_84_28075         dd 0x42a88fbe
FCONST_32767_0          dd 0x46fffe00
ICONST_2147483648       dd 0x80000000
ICONST_1034594986       dd 0x3daaaaaa
ICONST_24               dd 0x18

