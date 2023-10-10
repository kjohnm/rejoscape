    processor 6502

;; Arquivos de Macro e VCS

    include "vcs.h"
    include "macro.h"

;; Declaração das var  (memódia do end. $80 a $FF)

    seg.u Variables
    org $80

PZeroXPos       byte         
PZeroYPos       byte         
PolicialXPos    byte       
PolicialYPos    byte       
TiroXPos        byte         ; Posição  x do tiro
TiroYPos        byte         ; Pos Y do tiro
Score           byte         ; Score armazenado no BCD
Timer           byte         ; Tempo
Temp            byte         ; Variavel Auxiliar temporaria
OnesDigitOffset word         ; Deslocamento da tabela de pontuação (Dígito das unidades)
TensDigitOffset word         ; Deslocamento para Dezenas
PZeroSpritePtr  word         ; Ponteiro para Sprite (obj que vai ser mexido na tela) do P0 na tabela
PZeroPtr        word         ; Ponteiro para cor do P0 na tabela
PolicialSpritePtr word       ; Ponteiro do Sprite do Policial na tabela
PolicialCorPtr  word         ; Ponteiro do Sprite para cor do policial
PZeroAnimOffset byte         ; Usado para aux a controlar a animação
Random          byte         ; Usado para gerar a pos inicial do policial
ScoreSprite     byte         ; Armazena o padrao de bits do score
TimerSprite     byte         ; Armazena o Padrao de bits do temporizador
CorTerreno      byte         ; Armazena a cor do terreno (Parte Lateral)
CorCentro       byte         ; Armazena a Cor do Centro
TiroDisparado   byte         ; Armazena se o tiro foi disparado

;; Definindo constantes

PZero_ALTURA = 9             ; Altura do P0
Policial_ALTURA = 9          ; Altura do Policial
Digitos_ALTURA = 5           ; Altura do Score

;; Iniciando a Rom no endereço de memória F000
    seg Code
    org $F000

Reset:
    CLEAN_START              ; chamando o macro p/ limpar memoria e registradores

;; Iniciando as variáveis na memoria RAM

    lda #68
    sta PZeroXPos              ; PZeroXPos = 68
    lda #10
    sta PZeroYPos              ; PZeroYPos = 10
    lda #62
    sta PolicialXPos           ; PolicialXPos = 62
    lda #83
    sta PolicialYPos           ; PolicialYPos = 83
    lda #%11010100
    sta Random               
    lda #0
    sta Score                  ; Score = 0
    sta Timer                  ; Timer = 0
    

;; Declarando o macro para chegar o display do tiro

    MAC DRAW_Tiro
        lda #%00000000
        cpx TiroYPos        ; compare X (linha atual) com TiroYpos
        bne .SkipTiroDraw   ; if (X != PosY do tiro), entao avança
.DrawTiro:                  ; else:
        lda #%00000010      ;     ativa display do tiro 
        inc TiroYPos        ;     TiroYPos++
.SkipTiroDraw:
        sta ENAM0           ; Armazena o valor correto no registrador TIA
    ENDM

;; Inicializando os ponteiros para a tabela de endereços

    lda #<PZeroSprite
    sta PZeroSpritePtr         ; ponteiro lo-byte (bit - significativo) p/ tabela de sprite do PZero 
    lda #>PZeroSprite
    sta PZeroSpritePtr+1       ; ponteiro hi-byte (bit + significativo) p/ tabela de sprite do PZero 

    lda #<PZero
    sta PZeroPtr          ; ponteiro lo-byte para tabela de cor do PZero 
    lda #>PZero
    sta PZeroPtr+1        ; ponteiro hi-byte para tabela de cor do PZero 

    lda #<PolicialSprite
    sta PolicialSpritePtr      ; ponteiro lo-byte para tabela de sprite do policial
    lda #>PolicialSprite
    sta PolicialSpritePtr+1    ; ponteiro hi-byte para tabela de sprite do policial

    lda #<PolicialCor
    sta PolicialCorPtr       ; ponteiro lo-byte para tabela de cor do policial
    lda #>PolicialCor
    sta PolicialCorPtr+1     ; ponteiro hi-byte para tabela de cor do policial


;; Iniciando a tela principal e renderizando os frames

StartFrame:

;; VSYNC e VBLANK
;;VSYNC (Vertical Synchronization): é o sinal ou técnica usada em sistemas de vídeo para garantir que o quadro 
;;atual seja exibido inteiro antes de começar a exibir o próximo. Isso ajuda a evitar erros visuais. 
;;O "VSYNC" é usado para controlar quando a sincronização vertical ocorre.

;;VBLANK (Vertical Blank): é o período durante o qual o feixe de elétrons do monitor volta da parte inferior de 
;;sua tela para o topo, geralmente fora da visão do usuário. Durante esse período, nenhum pixel é desenhado na tela, 
;;permitindo que a memória de vídeo seja atualizada sem interferência. O registro ou variável "VBLANK" está sendo usada 
;;para indicar o início ou o término do período de VBLANK.

    lda #2
    sta VBLANK               ; Inicia VBLANK
    sta VSYNC                ; Inicia VSYNC
    REPEAT 3
        sta WSYNC            ; Mostrando as linhas recomendadas do VSYNC
    REPEND
    lda #0
    sta VSYNC                ; Desliga VSYNC
    REPEAT 31
        sta WSYNC            ; Mostra recomendações do VBLANK
    REPEND

;; Calculos e tarefas durante a seção de VBLANK

    lda PZeroXPos
    ldy #0
    jsr SetPosXobj        ; Seta a posição horizontal do P0

    lda PolicialXPos
    ldy #1
    jsr SetPosXobj        ; Seta Posição horizontal do policial

    lda TiroXPos
    ldy #2
    jsr SetPosXobj        ; Seta a pos horizontal do tiro

    jsr CalcDigitoOffSet ; Calcula os digitos do scoreboard

    ;jsr GenSomPZero     ; Configura e habilita o audio do P0

    sta WSYNC
    sta HMOVE                ; aplica o offset horizontal

    lda #0
    sta VBLANK               ; desliga VBLANK

;; Linhas do scoreboard

    lda #0                   ; Reseta os registradores TIA antes de mostrar o Score
    sta COLUBK
    sta PF0
    sta PF1
    sta PF2
    sta GRP0
    sta GRP1
    sta CTRLPF

    lda #$C2
    sta COLUPF               ; Seta a Cor do ScoreBoard, nesse caso "C2", que é verd

    ldx #Digitos_ALTURA       ; Starta o contador com 5, que é a altura constante dos digitos

.ScoreDigitLoop:
    ldy TensDigitOffset      ; Obtem o deslocamento da dezena para o Score
    lda Digitos,Y            ; Carrega o padrão de bits da tabela de pesquisa
    and #$F0                 ; Mascara/elimina os gráficos para o dígito das unidades
    sta ScoreSprite          ; Salva o padrão de dezenas do Score em uma variável

    ldy OnesDigitOffset      ; Obte o deslocamento da unidade para o Score
    lda Digitos,Y            ; Carrega o padrão de bits do dígito da tabela de pesquisa
    and #$0F                 ; Mascara/elimina os gráficos para o dígito das dezenas
    ora ScoreSprite          ; Mescla com o sprite de dezenas do Score salvo
    sta ScoreSprite          ; e salva

    sta WSYNC                ; Aguarda o final da varredura da linha
    sta PF1                  ; Atualiza o campo de jogo para exibir o sprite do Score

    ldy TensDigitOffset+1    ; Obtem o deslocamento do dígito da esquerda para o Timer
    lda Digitos,Y            ; Carrega o padrão de dígito da tabela de pesquisa
    and #$F0                 ; Mascara/elimina os gráficos para o dígito das unidades
    sta TimerSprite          ; Salva o padrão de dezenas do Timer em uma variável

    ldy OnesDigitOffset+1    ; Obtem o deslocamento da unidade para o Timer
    lda Digitos,Y            ; Carrega o padrão de bits do dígito da tabela de pesquisa
    and #$0F                 ; Mascara/elimina os gráficos para o dígito das dezenas
    ora TimerSprite          ; Mescla com os gráficos de dezenas do Timer salvos
    sta TimerSprite          ; e salvar

    jsr Sleep12Cycles        ; Aguardar alguns ciclos

    sta PF1                  ; Atualiza o campo de jogo para exibir o Timer

    ldy ScoreSprite          ; Pré-carrega para a próxima linha de varredura
    sta WSYNC                ; Aguarda a próxima linha de varredura

    sty PF1                  ; Atualiza o campo de jogo para exibir o Score
    inc TensDigitOffset
    inc TensDigitOffset+1
    inc OnesDigitOffset
    inc OnesDigitOffset+1    ; Incrementar todos os deslocamentos para os próximos dados da linha

    jsr Sleep12Cycles        ; Aguarda alguns ciclos

    dex                      ; X--
    sta PF1                  ; Atualiza o campo de jogo para exibir o Timer
    bne .ScoreDigitLoop      ; Se dex != 0, então volta para ScoreDigitLoop

    sta WSYNC

    lda #0
    sta PF0
    sta PF1
    sta PF2
    sta WSYNC
    sta WSYNC
    sta WSYNC

;; Tela do restante das linhas do jogo

GameVisibleLine:
    lda CorTerreno
    sta COLUPF               ; Seta a cor do terreno (parte lateral)

    lda CorCentro
    sta COLUBK               ; Seta a cor do centro

    lda #%00000001
    sta CTRLPF               ; Habilita a reflexao do playfield
    lda #$F0
    sta PF0                  ; Seta o padrao de bit PF0
    lda #$FC
    sta PF1                  ; Seta o padrao de bit PF1
    lda #0
    sta PF2                  ; Seta o padrao de bit PF2

    ldx #89                  ; Contador X para o restante das linhas
.GameLineLoop:
    DRAW_Tiro                ; Macro pra checar se o tiro foi efetuado/puxado

.AreWeInsidePZeroSprite:
    txa                      ; transfere X para A
    sec                      ; garante que a flag de carry esteja definida antes da subtração
    sbc PZeroYPos            ; subtrai a coordenada Y do sprite
    cmp #PZero_ALTURA        ; compara se estamos dentro dos limites da altura do sprite
    bcc .DrawSpriteP0        ; se o resultado for < Altura do Sprite, chama a rotina de desenho
    lda #0                   ; caso contrário, define o índice de pesquisa como zero
.DrawSpriteP0:
    clc                      ; limpa a flag de carry antes da adição
    adc PZeroAnimOffset      ; salta para o endereço correto do quadro do sprite na memória
    tay                      ; carrega Y para que possamos trabalhar com o ponteiro
    lda (PZeroSpritePtr),Y   ; carrega dados do bitmap do p0 a partir da tabela de pesquisa
    sta WSYNC                ; espera pela varredura de linha
    sta GRP0                 ; define a gráfica para o p0
    lda (PZeroPtr),Y         ; carrega a Cor do Pzero a partir da tabela de pesquisa
    sta COLUP0               ; define a Cor do Pzero

.AreWeInsidePolicialSprite:
    txa                      ; transfere X para A
    sec                      ; garante que a flag de carry esteja definida antes da subtração
    sbc PolicialYPos         ; subtrai a coordenada Y do sprite policial
    cmp #Policial_ALTURA     ; compara se estamos dentro dos limites da altura do sprite
    bcc .DrawSpriteP1        ; se o resultado for < Altura do Sprite, chama a rotina de desenho
    lda #0                   ; caso contrário, define o índice de pesquisa como zero
.DrawSpriteP1:
    tay                      ; carrega Y para que possamos trabalhar com o ponteiro

    lda #%00000101
    sta NUSIZ1               ; estica o sprite Policial

    lda (PolicialSpritePtr),Y   ; carrega dados do bitmap do policial a partir da tabela de pesquisa
    sta WSYNC                   ; espera pela varredura de linha
    sta GRP1                    ; define a gráfica para o policial
    lda (PolicialCorPtr),Y      ; carrega a Cor do policial a partir da tabela de pesquisa
    sta COLUP1                  ; define a Cor do Policial

    dex                      ; X--
    bne .GameLineLoop        ; repete a próxima varredura principal do jogo até terminar

    lda #0
    sta PZeroAnimOffset        ; redefine o quadro de animação do p0 como zero a cada quadro

    sta WSYNC                ; espera por uma varredura de linha

;; Display VBLANK Overscan

    lda #2
    sta VBLANK               ; turn on VBLANK again to display overscan
    REPEAT 30
        sta WSYNC            ; display recommended lines of overscan
    REPEND
    lda #0
    sta VBLANK               ; turn off VBLANK

;; Controladores

CheckP0Up:
    lda #%00010000           ; joystick cima p/ Pzero
    bit SWCHA
    bne CheckP0Down
    lda PZeroYPos
    cmp #60                  ; if (p0 pos Y > 60)
    bpl CheckP0Down          ;    then: n incrementa
.P0UpPressed:                ;    else:
    inc PZeroYPos              ;        incrementa pos Y
    lda #0
    sta PZeroAnimOffset        ;        Seta animação do P0 p/ 0

CheckP0Down:
    lda #%00100000           ; joystick baixo p/ Pzero
    bit SWCHA
    bne CheckP0Left
    lda PZeroYPos
    cmp #5                   ; if (p0 pos Y < 5)
    bmi CheckP0Left          ;    then: pula decremento (não decresce)
.P0DownPressed:              ;    else:
    dec PZeroYPos              ;        decresce pos Y
    lda #0
    sta PZeroAnimOffset        ;        Seta animação do P0 p/ 0

CheckP0Left:
    lda #%01000000           ; joystick esquerda para o Pzero
    bit SWCHA
    bne CheckP0Right
    lda PZeroXPos
    cmp #35                  ; if (p0 pos X < 35)
    bmi CheckP0Right         ;    then: skip decrement
.P0LeftPressed:              ;    else:
    dec PZeroXPos              ;        decrementa pos X
    lda #PZero_ALTURA
    sta PZeroAnimOffset        ;        seta novo offset p/ mostrar 

CheckP0Right:
    lda #%10000000           ; joystick direita p/ Pzero
    bit SWCHA
    bne CheckButtonPressed
    lda PZeroXPos
    cmp #100                 ; if (p0 pos X > 100)
    bpl CheckButtonPressed   ;    then: não incrementa
.P0RightPressed:             ;    else:
    inc PZeroXPos              ;        incrementa pos X
    lda #PZero_ALTURA
    sta PZeroAnimOffset        ;        seta novo offset p/ mostrar 

CheckButtonPressed:
    lda #%10000000           ; se o btn está pressionado
    bit INPT4
    bne EndInputCheck
ButtonPressed:
    lda PZeroXPos
    clc
    adc #5
    sta TiroXPos          ; Seta Tiro pos X igual a Pzero
    lda PZeroYPos
    clc
    adc #8
    sta TiroYPos          ; Seta Tiro pos Y igual a Pzero
    lda #1                ; Define a variável Tiro disparado como 1 para indicar que um tiro foi disparado
    sta TiroDisparado

EndInputCheck:               

;; Calculo da atualização da pos para o prox frame

UpdatePolicialPosition:
    lda PolicialYPos
    clc
    cmp #0                     ; compara a posição Y do Policial com 0
    bmi .ResetPolicialPosition ; se for < 0, então redefine a posição Y para o topo
    dec PolicialYPos           ; caso contrário, decrementa a posição Y do inimigo para o próximo quadro
    jmp EndPositionUpdate      ; salta para o final da atualização de posição
.ResetPolicialPosition:
    jsr GetRandomPolicialPos   ; chama a sub-rotina para definir a posição aleatória do Policial

.SetScoreValues:
    sed                      ; define o modo BCD para os valores de pontuação e tempo
    lda Timer
    clc
    adc #1
    sta Timer                ; adiciona 1 ao Timer (BCD não gosta de INC!!!)
    cld                      ; desabilita o modo BCD após atualizar Score e Timer

EndPositionUpdate:           ; fallback para o código de atualização de posição

;; Verificando colisão de objetos
CheckCollisionP0P1:
    lda #%10000000           ; o bit 7 do CXPPMM detecta colisão entre P0 e o Policial
    bit CXPPMM               ; verifica o bit 7 do CXPPMM com o padrão acima
    bne .P0P1Collided        ; se a colisão entre P0 e P1 aconteceu, então é game over
    jsr SetCoresTerreno      ; se a colisao n aconteceu, define as cores do terreno
    jmp CheckCollisionM0P1   ; verifica a próxima colisão possível
.P0P1Collided:
    jsr GameOver             ; chama a sub-rotina GameOver

CheckCollisionM0P1:
    lda #%10000000           ; o bit 7 do CXM0P detecta colisão entre M0 e P1
    bit CXM0P                ; verifica o bit 7 do CXM0P com o padrão acima
    bne .M0P1Collided        ; colisão entre Tiro e Policial aconteceu
    jmp EndCollisionCheck    ; salta para o final da verificação de colisão
.M0P1Collided:
    sed
    lda Score
    clc
    adc #1
    sta Score                ; adiciona 1 à pontuação usando o modo decimal
    cld
    lda #0
    sta TiroYPos             ; redefine a posição do Tiro
EndCollisionCheck:           ; 
    sta CXCLR                ; limpa todas as flags de colisão antes do próximo quadro


;; loop para iniciar novo frame
    jmp StartFrame           ; continua p/ tela do prox frame

;;Subrotina de som
GenSomPZero subroutine
    lda TiroDisparado     ; Verifique se um tiro foi disparado
    beq NoSound           ; Se não, pule a geração de som

    lda #2
    sta AUDV0             ; Ajuste o volume do áudio

    lda #8
    sta AUDC0             ; Controle de áudio

    lda #30               ; Ajuste da frequência do som
    sec
    sbc Temp
    sta AUDF0             ; Frequência do áudio

    ; Redefino a variável TiroDisparado para 0 para indicar que o som já foi gerado
    lda #0
    sta TiroDisparado

    ;jsr GenSomPZero  ; Chamo novamente a geração de som

NoSound:
    rts

;; Define as cores do terreno e do centro
SetCoresTerreno subroutine
    lda #$02
    sta CorTerreno         ; Seta cor do terreno para cinza escuro
    lda #$04
    sta CorCentro          ; Seta a cor do centro para cinza claro
    rts

;; Subrotina para lidar com a posição horizontal do objeto com ajuste fino

SetPosXobj subroutine
    sta WSYNC                ; inicia uma nova varredura limpa
    sec                      ; garante que o carry-flag esteja definido antes da subtração
.Div15Loop
    sbc #15                  ; subtrai 15 do acumulador
    bcs .Div15Loop           ; loop até que o carry-flag esteja limpo
    eor #7                   ; trata a faixa de deslocamento de -8 a 7
    asl
    asl
    asl
    asl                      ; quatro shifts para a esquerda para obter apenas os 4 bits superiores
    sta HMP0,Y               ; armazena o ajuste fino no HMxx correto
    sta RESP0,Y              ; corrige a posição do objeto em incrementos de 15 etapas
    rts

;; Subrotina de GameOver

GameOver subroutine
    lda #$01
    sta CorTerreno           ; define cor do terreno p/ preto
    lda #$30
    sta CorCentro            ; define cor do terreno p/ vermelho
    lda #0
    sta Score                ; Score = 0
    rts

;; Subrotina para gerar o num randomico
;; Gere um número aleatório LFSR para a posição X do Policial.
;; Divida o valor aleatório por 4 para limitar o tamanho do resultado para combinar com o centro.
;; Adicione 30 para compensar a parte esquerda do playfield.
;; A rotina também define a posição Y do Policial no topo da tela.
GetRandomPolicialPos subroutine
    lda Random
    asl
    eor Random
    asl
    eor Random
    asl
    asl
    eor Random
    asl
    rol Random                  ; realiza uma série de deslocamentos e operações de bits
    lsr
    lsr                         ; divide o valor por 4 com 2 deslocamentos à direita
    sta PolicialXPos            ; salva-o na variável PolicialXPos
    lda #30
    adc PolicialXPos            ; adiciona 30 + PolicialXPos para compensar a parte esquerda do PF
    sta PolicialXPos            ; e define o novo valor para a posição X do Policial

    lda #96
    sta PolicialYPos           ; define a posição Y no topo da tela

    rts

;; Sub-rotina para lidar com os dígitos do placar a serem exibidos na tela

;; O placar é armazenado em BCD, então a exibição mostra números hexadecimais.
;; Isso converte os nibbles altos e baixos da variável Score e Timer
;; nos deslocamentos da tabela de pesquisa Digitos para que os valores possam ser exibidos.
;; Cada dígito tem uma ALTURA de 5 bytes na tabela de pesquisa.
;;
;; Para baixo, precisamos multiplicar por 5
;;   - podemos usar deslocamentos à esquerda para multiplicação por 2
;;   - para qualquer número N, o valor de N*5 = (N*2*2)+N
;;
;; Para a parte superior, como já está multiplicado por 16, precisamos dividi-lo
;; e depois multiplicá-lo por 5:
;;   - podemos usar deslocamentos à direita para a divisão por 2
;;   - para qualquer número N, o valor de (N/16)*5 é igual a (N/4)+(N/16)

CalcDigitoOffSet subroutine
    ldx #1                   ; O registro X é o contador de loop
.PrepareScoreLoop            ; isso fará loop duas vezes, primeiro X=1 e depois X=0

    lda Score,X              ; carrega A com Timer (X=1) ou Score (X=0)
    and #$0F                 ; remove o dígito das dezenas mascarando 4 bits 00001111
    sta Temp                 ; salva o valor de A em Temp
    asl                      ; desloca à esquerda (agora é N*2)
    asl                      ; desloca à esquerda (agora é N*4)
    adc Temp                 ; adiciona o valor salvo em Temp (+N)
    sta OnesDigitOffset,X    ; salva A em OnesDigitOffset+1 ou OnesDigitOffset

    lda Score,X              ; carrega A com Timer (X=1) ou Score (X=0)
    and #$F0                 ; remove o dígito das unidades mascarando 4 bits 11110000
    lsr                      ; desloca à direita (agora é N/2)
    lsr                      ; desloca à direita (agora é N/4)
    sta Temp                 ; salva o valor de A em Temp
    lsr                      ; desloca à direita (agora é N/8)
    lsr                      ; desloca à direita (agora é N/16)
    adc Temp                 ; adiciona o valor salvo em Temp (N/16+N/4)
    sta TensDigitOffset,X    ; armazena A em TensDigitOffset+1 ou TensDigitOffset

    dex                      ; X--
    bpl .PrepareScoreLoop    ; enquanto X >= 0, faça um loop para passar uma segunda vez

    rts

;; Sub-rotina para gastar 12 ciclos
;; jsr leva 6 ciclos
;; rts leva 6 ciclos

Sleep12Cycles subroutine
    rts

;; Declarar tabelas de pesquisa ROM

Digitos:
    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01010101          ; # # # #
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###

    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #

    .byte %01110111          ; ### ###
    .byte %00010001          ;   #   #
    .byte %01110111          ; ### ###
    .byte %01000100          ; #   #
    .byte %01110111          ; ### ###

    .byte %01110111          ; ### ###
    .byte %00010001          ;   #   #
    .byte %00110011          ;  ##  ##
    .byte %00010001          ;   #   #
    .byte %01110111          ; ### ###

    .byte %01010101          ; # # # #
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #

    .byte %01110111          ; ### ###
    .byte %01000100          ; #   #
    .byte %01110111          ; ### ###
    .byte %00010001          ;   #   #
    .byte %01110111          ; ### ###

    .byte %01110111          ; ### ###
    .byte %01000100          ; #   #
    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###

    .byte %01110111          ; ### ###
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #

    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###

    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###
    .byte %00010001          ;   #   #
    .byte %01110111          ; ### ###

PZeroSprite:
    .byte #%00000000;$0E
    .byte #%10010010;$0E
    .byte #%11110101;$0E
    .byte #%00111011;$0E
    .byte #%11110101;$0E
    .byte #%10010010;$0E
    .byte #%00011000;$40
    .byte #%00001000;$40
    .byte #%00000000;--

PZeroSpriteTurn:
    .byte #%00000000;$0E
    .byte #%01001001;$0E
    .byte #%10101111;$0E
    .byte #%11011100;$0E
    .byte #%10101111;$0E
    .byte #%01001001;$0E
    .byte #%00011000;$40
    .byte #%00010000;$40
    .byte #%00000000;--

PolicialSprite:
    .byte #%00000000;$0E
    .byte #%00110110;$0E
    .byte #%00011100;$0E
    .byte #%01011101;$90
    .byte #%01111111;$90
    .byte #%00110110;$26
    .byte #%00101010;$26
    .byte #%00111111;$90
    .byte #%00111110;$80

;;Cores
PZero:
    .byte #$00;
    .byte #$0E;
    .byte #$0E;
    .byte #$0E;
    .byte #$0E;
    .byte #$0E;
    .byte #$40;
    .byte #$40;
    .byte #$0E;

PZeroTurn:
    .byte #$00;
    .byte #$0E;
    .byte #$0E;
    .byte #$0E;
    .byte #$0E;
    .byte #$0E;
    .byte #$40;
    .byte #$40;
    .byte #$0E;

PolicialCor:
    .byte #$00;
    .byte #$00;
    .byte #$00;
    .byte #$90;
    .byte #$90;
    .byte #$26;
    .byte #$26;
    .byte #$90;
    .byte #$80;

;; Completando tamanho da ROM com exatos 4KB
    org $FFFC                ; movendo p/ posição $FFFC
    word Reset               ; escrevendo 2 bytes com reset de endereço
    word Reset               ; escrevendo 2 bytes com o vetor de interrup
