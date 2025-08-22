; Amphibian-Crossing Simulation
; Autor: [Tu Nombre Completo]
; Universidad: Pontificia Universidad Javeriana, Cali
; Programa: Matemáticas Aplicadas e Ingeniería en Sistemas
; Año: 2025
; Descripción: Modelo basado en la idea de Crevier et al. (2021),
; modificado para simular el movimiento de sapos y pollas de agua
; en paisajes fragmentados con pasos verdes y zonas de alimentación.
; Licencia: MIT / CC BY-NC-SA 4.0 (elige la adecuada)


;; Declaración de tipos de agentes)
breed [ zonasalimentacion  zonaalimentacion ]   ; Agentes tipo zonadealimentacion
breed [ walkers walker ]       ; Agentes tipo caminantes

;; Propiedades propias de los walkers
walkers-own [ goal attempts necesidad-de-alimentacion tipo ]  ; goal = destino actual, attempts = intentos fallidos de cruce

;; Propiedades propias de los parches
patches-own [ popularity ]     ; Nivel de popularidad de cada parche

;; Propiedades de las zonas de alimentacion
zonasalimentacion-own [ciclos estacional?];

;; Variables globales
;globals [ mouse-clicked? repulsion-probability ]  ; mouse-clicked? evita múltiples clics seguidos, repulsion-probability regula la probabilidad de evitar cruzar una línea
globals [ mouse-clicked? ticks-sin-zona ]

;; Inicialización del mundo
to setup
  clear-all
  ask patches [ set pcolor green ]
  ask patches with [ pycor = 0 ] [ set pcolor black ]
  set-default-shape zonasalimentacion "target"
  set ticks-sin-zona 0

  ask patches with [pycor = 0 and pxcor >= iniciopaso and pxcor <= iniciopaso + 6] [
    set pcolor lime
  ]
  ask patches with [pcolor = lime] [
    set popularity minpopularity_corredor
  ]


  ;; Crear zona permanente
  create-zonasalimentacion 1 [
    setxy -25 20
    set color blue   ;; Color diferente para distinguir
    set size 3
    set ciclos 0
    set estacional? false
  ]

  ;; Crear zona estacional
  create-zonasalimentacion 1 [
    setxy 10 -30
    set color red
    set size 3
    set ciclos 0
    set estacional? true
  ]

  ;; Crear walkers
  ;; Crear walkers tipo 1 (80%)
create-walkers round (walker-count * 0.8) [
  setxy random-xcor random-ycor
  set goal one-of patches
  set color yellow
  set size 2
  set attempts 0
  set tipo 1
  set necesidad-de-alimentacion necesidad-tipo1
]

;; Crear walkers tipo 2 (20%)
create-walkers (walker-count - count walkers) [
  setxy random-xcor random-ycor
  set goal one-of patches
  set color magenta
  set size 2
  set attempts 0
  set tipo 2
  set necesidad-de-alimentacion necesidad-tipo2
]


  reset-ticks
end



;; Loop principal que se ejecuta cada tick
to go
  move-walkers
  actualizar-zonas-alimentacion
  decay-popularity
  recolor-patches
  tick
end




;; Disminuye popularidad si el parche no está siendo visitado
to decay-popularity
  ask patches with [not any? walkers-here and pcolor != lime] [
    set popularity popularity * (100 - popularity-decay-rate) / 100

    if popularity < 1 [
      if pycor = 0 [ set pcolor black ]
      if pycor != 0 [ set pcolor green ]
    ]
  ]

  ;; Asegura que los lime no bajen de 6
  ask patches with [pcolor = lime] [
    if popularity < minpopularity_corredor [ set popularity minpopularity_corredor ]
  ]
end



;; Aumenta popularidad si un agente pasa por el parche
to become-more-popular
  set popularity popularity + popularity-per-step
  if popularity >= minimum-route-popularity [ set pcolor gray ] ; Se vuelve una "ruta"
end

;; Movimiento de los walkers
to move-walkers
  ask walkers [
    ifelse patch-here = goal [             ; Si llegaron a su meta
      ifelse random-float 1 < necesidad-de-alimentacion [ ;¿que tanto come un animal necesidad de alimentacion
        set goal [ patch-here ] of one-of zonasalimentacion ; Si hay zonas de alimentacion, escoge uno como nueva meta bajo cierta probabilidad
        set attempts 0
      ] [
        set goal one-of patches                     ; Si no hay o no tiene necesidad de comer, meta aleatoria
        set attempts 0
      ]
    ] [
      walk-towards-goal                            ; Si no han llegado, caminan hacia su meta
    ]
  ]
end

;; Determina si el siguiente paso cruzará la línea de repulsión (pycor = 0)
to-report will-cross-repulsion-line?
  let next-step patch-ahead 1
  let y-now pycor
  let y-next [pycor] of next-step

  ;; Detecta cruce de línea (cambio de signo en pycor)
  let cruzando-linea? (y-now > 0 and y-next <= 0) or (y-now < 0 and y-next >= 0)

  ;; Verifica si el parche de destino es un paso verde (lime)
  let paso-verde? [pcolor] of next-step = lime

  ;; Solo se considera un cruce con repulsión si no es paso verde
  report cruzando-linea? and not paso-verde?
end



;; Lógica del movimiento hacia la meta, incluyendo el cruce de la línea de repulsión
to walk-towards-goal
  ;; Si no está sobre una ruta, incrementa la popularidad del parche actual
  if pcolor != gray [
    ask patch-here [ become-more-popular ]
  ]

  face best-way-to goal  ;; Gira hacia su meta

  let crossing-line? will-cross-repulsion-line?

  ;; Si repulsion total (prob = 1), no intenta cruzar, cambia de meta
  if (tipo = 1 and repulsion-tipo1 = 1) or (tipo = 2 and repulsion-tipo2 = 1) [
    if crossing-line? [
      set attempts 0
      ifelse count zonasalimentacion >= 2 [
        set goal [patch-here] of one-of zonasalimentacion
        set attempts 0
      ][
        set goal one-of patches
        set attempts 0
      ]
      stop
    ]
  ]

  ;; Si está cruzando la línea de repulsión
  if crossing-line? [
    let max-attempts ifelse-value (tipo = 1) [8] [10]
    let repulsion ifelse-value (tipo = 1) [repulsion-tipo1] [repulsion-tipo2]

    ifelse random-float 1 < repulsion and attempts < max-attempts [
      set attempts attempts + 1
      rt one-of [-45 45]  ;; Gira aleatoriamente a izquierda o derecha
      stop
    ][
      ;; Probabilidad de morir si cruza
      if random-float 1 < mortality-probability [
        die
        stop
      ]
      fd 1
      stop
    ]
  ]
  ;; Si no hay cruce o no se aplica repulsión, avanza normalmente
  fd 1
end

;; Determina la mejor ruta visual hacia el destino
to-report best-way-to [ destination ]
  let visible-patches patches in-radius walker-vision-dist

  ;; Considera parches grises (rutas emergentes) y lime (paso verde)
  let visible-routes visible-patches with [ pcolor = gray or pcolor = lime ]

  let routes-that-take-me-closer visible-routes with [
    distance destination < [ distance destination - 1 ] of myself
  ]

  ifelse any? routes-that-take-me-closer [
    report min-one-of routes-that-take-me-closer [ distance self ]
  ] [
    report destination
  ]
end


;; Colorea los parches según su popularidad si está activado el flag show-popularity?
to recolor-patches
  ifelse show-popularity? [
    let max-value (minimum-route-popularity * 3)
    ask patches with [
      pcolor != gray and pcolor != lime and pycor != 0
    ] [
      set pcolor scale-color green popularity (- max-value) max-value
    ]
  ] [
    ask patches with [
      pcolor != gray and pcolor != lime and pycor != 0
    ] [
      set pcolor green
    ]
  ]

  ;; Restaurar el color lime si algún paso verde fue sobrescrito
  ;; por ejemplo: en pxcor de -3 a 3 sobre la carretera (pycor = 0)
  ask patches with [pycor = 0 and pxcor >= iniciopaso and pxcor <= iniciopaso + 6] [
    set pcolor lime
  ]
end



;; NUEVA versión de actualizar-zonas-alimentacion
to actualizar-zonas-alimentacion
  ;; Para las zonas estacionales activas
  ask zonasalimentacion with [ estacional? ] [
    set ciclos ciclos + 1

    ;; Cambiar de color cuando esté a punto de desaparecer
    if ciclos >= ticksfuente - 20 and ciclos < ticksfuente [
      set color orange  ;; entre tick 90 y 99 cambia a naranja
    ]

    ;; Cuando llega a 100 ticks, desaparece
    if ciclos = ticksfuente [
      die
      set ciclos 0    ;; importante para luego usar este control de reaparecer
    ]
  ]

  ;; Cuando no haya zona estacional presente, empieza un contador para reaparecer
  if count zonasalimentacion with [ estacional? ] = 0 [
    ;; Usamos una variable global para contar los ticks sin zona estacional
    set ticks-sin-zona ticks-sin-zona + 1

    ;; Cuando hayan pasado 100 ticks sin zona, reaparece
    if ticks-sin-zona >= ticksfuente [
      create-zonasalimentacion 1 [
        setxy 10 -30        ;; Mismo lugar fijo
        set color red      ;; Vuelve a ser roja al aparecer
        set size 3
        set ciclos 0
        set estacional? true
      ]
      set ticks-sin-zona 0  ;; Reinicia contador
    ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
217
21
629
434
-1
-1
4.0
1
10
1
1
1
0
0
0
1
-50
50
-50
50
0
0
1
ticks
30.0

BUTTON
25
36
88
69
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
98
37
161
70
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
23
171
197
204
walker-count
walker-count
1
500
164.0
1
1
NIL
HORIZONTAL

SLIDER
23
127
196
160
popularity-decay-rate
popularity-decay-rate
0
100
10.0
1
1
%
HORIZONTAL

SLIDER
24
214
199
247
minimum-route-popularity
minimum-route-popularity
0
100
76.0
1
1
NIL
HORIZONTAL

SLIDER
23
84
195
117
popularity-per-step
popularity-per-step
0
100
27.0
1
1
NIL
HORIZONTAL

SLIDER
23
260
199
293
walker-vision-dist
walker-vision-dist
1
30
18.0
1
1
NIL
HORIZONTAL

SWITCH
22
352
173
385
show-popularity?
show-popularity?
1
1
-1000

SLIDER
659
63
853
96
repulsion-tipo1
repulsion-tipo1
0
1
0.9
0.1
1
NIL
HORIZONTAL

SLIDER
659
21
852
54
necesidad-tipo1
necesidad-tipo1
0
1
0.7
0.1
1
NIL
HORIZONTAL

SLIDER
859
21
1051
54
necesidad-tipo2
necesidad-tipo2
0
1
0.3
0.1
1
NIL
HORIZONTAL

MONITOR
763
109
851
154
Walkers Tipo 1 
count walkers with [tipo = 1]
17
1
11

MONITOR
861
108
956
153
Walkers tipo 2
count walkers with [tipo = 2]
17
1
11

SLIDER
22
304
197
337
mortality-probability
mortality-probability
0
1
0.08
0.01
1
NIL
HORIZONTAL

PLOT
656
169
1049
413
plot 1
NIL
NIL
0.0
50.0
0.0
50.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count walkers with [tipo = 1]"
"pen-1" 1.0 0 -5825686 true "" "plot count walkers with [tipo = 2]"

SLIDER
859
61
1051
94
repulsion-tipo2
repulsion-tipo2
0
1
0.7
0.1
1
NIL
HORIZONTAL

SLIDER
23
397
204
430
minpopularity_corredor
minpopularity_corredor
10
60
21.0
1
1
NIL
HORIZONTAL

SLIDER
1075
100
1247
133
ticksfuente
ticksfuente
100
2000
400.0
100
1
NIL
HORIZONTAL

INPUTBOX
1079
190
1144
250
iniciopaso
-30.0
1
0
Number

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
