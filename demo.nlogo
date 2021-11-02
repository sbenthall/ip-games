globals []
breed [products product]
breed [consumers consumer]
breed [ip-ranges ip-range]
breed [temp-ip-ranges temp-ip-range]
undirected-link-breed [ip-links ip-link]
undirected-link-breed [consumer-links consumer-link]

consumer-links-own [
  consumer-strength
  consumer-flow
]
ip-links-own [
  ip-strength
  ip-flow
]
temp-ip-ranges-own [
  temp-ip-power
  temp-radius
]
ip-ranges-own [
  ip-power
  radius
]
consumers-own [
  income
]
products-own [
  price
  revenue
  product-cost
]
patches-own [
  value
]

;; Setup Procedures ;;

to setup
  clear-all
  resize-world -20 20 -20 20

  set-default-shape ip-ranges "thin ring"
  set-default-shape temp-ip-ranges "thin ring"

  ask patches [
    if consumer-income = "random" [
      set value random 255
    ]
    if consumer-income = "constant" [
      set value constant-income
    ]
    render
    make-consumer
  ]
  make-product

  reset-ticks
end

;; Main Procedure  ;;

to compute-revenue
  ask consumer-links [ die ]

  ask consumers [

    ;; set up a condition for when consumer will chose general will-pay or ip-based will-pay

    will-pay
    let num-links count my-consumer-links
    ask my-consumer-links [
      set consumer-strength 1.0 / num-links
      set color (list (150 / num-links) (150 / num-links) (150 / num-links))
      set consumer-flow consumer-strength * [value] of myself
    ]
  ]

  ask products [
    let x-price price
    set revenue sum [min (list x-price consumer-flow)] of my-consumer-links
  ]

  set-current-plot "product revenue"
  clear-plot
  set-current-plot-pen "revenue"
  set-plot-pen-interval 1
  set-plot-x-range 0 max-pxcor
  set-plot-y-range 0 max-pycor

  ;; sort revenue and plot in descending order
  let sort-rev reverse sort [revenue] of products
  foreach sort-rev [x -> plot x]

end

;; Initial Conditions ;;

to render
  set pcolor (list 0 value 0)
end

to make-product
  ;;; a stopgap, establishes # of products on grid
  ;; set production cost and product placement
  if product-place = "random" [
    ask patches [
      if random-float 1.0 < random-dist-product-rate [
        sprout-products 1 [
          set-price
          set color (list price 0 0)
          set product-cost random 100 + 150
        ]
      ]
    ]
  ]
  if product-place = "even disp" [
    let pp even-dist-product-rate
    let pr round (world-width * pp)
    foreach (range min-pxcor max-pxcor pr)[
      x ->
      foreach (range min-pycor max-pycor pr) [
        y ->
        ask patch x y [
          sprout-products 1 [
            set-price
            set color (list price 0 0)
            set product-cost random 100 + 150
          ]
        ]
      ]
    ]
  ]
end

to make-consumer
  ;; setting income to the value of the patch while creating consumers
  sprout-consumers 1 [
    set size 0.1
    set color [pcolor] of patch-here
    set income [value] of patch-here
  ]
end

;; Pricing Procedures ;;

to will-pay
  ;; selecting buy strategy for consumers
    if buy-strategy = "no limit" [
    ask products with-min [
      price + (distance-weight * distance myself)
    ][create-consumer-link-with myself]
  ]
  if buy-strategy = "income driven" [
    ask products with-min [
      price + (distance-weight * distance myself)
    ][if ((price + (distance-weight * distance myself)) < [income] of myself) [create-consumer-link-with myself]]
  ]
end

to set-price
  if price-strategy = "constant" [
    set price constant-price
  ]
  if price-strategy = "random" [
    set price random 200 + 50
  ]
  if price-strategy = "economic driven" [
    set price product-cost + profit-margin
  ]
end

;; create a will-pay based on ip ranges
to must-buy-from
  if buy-strategy = "no limit" [
  ]
  if buy-strategy = "income driven" [
  ]
end

;; create random desire for profit margins
;; to-report profit-margin [profit]

to reprice-brute-force
  let revenues map reprice-revenue (range 0 255)
  let max-revenue max revenues

  set-current-plot "price vs revenue"
  clear-plot
  set-current-plot-pen "p-r"
  set-plot-pen-interval 1
  set-plot-x-range 0 max-pxcor
  set-plot-y-range 0 max-pycor

  foreach revenues [x -> plot x]

  set price position max-revenue revenues

  compute-revenue
end

to reprice-dichotomous
  let lower-bound 0
  let upper-bound 255

  let lower-bound-revenue reprice-revenue lower-bound
  let upper-bound-revenue reprice-revenue upper-bound

  let iterations 0

  let midpoint 0
  let midpoint-plus 0

  let midpoint-revenue 0
  let midpoint-plus-revenue 0

  while [upper-bound - lower-bound > 3] [
    set iterations iterations + 1

    set midpoint round ((upper-bound + lower-bound) / 2)
    set midpoint-plus midpoint + 1

    set midpoint-revenue reprice-revenue midpoint
    set midpoint-plus-revenue reprice-revenue midpoint-plus

    ifelse midpoint-revenue >= midpoint-plus-revenue [
      set upper-bound midpoint-plus
      set upper-bound-revenue midpoint-plus-revenue
    ] [
      set lower-bound midpoint
      set lower-bound-revenue midpoint-revenue
    ]
  ]

  ifelse midpoint-revenue > midpoint-plus-revenue [
    set price midpoint
  ][
    set price midpoint-plus
  ]

  output-type "i:"
  output-type iterations
  output-type " lb:"
  output-type lower-bound
  output-type " ub:"
  output-type upper-bound
  output-print ""

  output-type "mp:"
  output-type midpoint
  output-type " mpr:"
  output-type midpoint-revenue
  output-type " mp+r:"
  output-type midpoint-plus-revenue
  output-print ""

  set-current-plot "product repriced"
  clear-plot
  set-current-plot-pen "pen-0"
  set-plot-pen-interval 1
  set-plot-x-range 0 max-pxcor
  set-plot-y-range 0 max-pycor

  let sort-price reverse sort [price] of products
  foreach sort-price [x -> plot x]

  compute-revenue
end

to-report reprice-revenue [new-price]
  set price new-price
  set color (list price 0 0)

  compute-revenue

  report revenue
end

;; intellectual property interactions ;;

to ip-interact
  ;; strength or potential of ip for each product is held in ip-power value
  ;; determine if the ip of one product is invading the space of another
  ;; ask turtle for the distance to another turtle

  ; sort by turtle with higher ip-power (probably not perfect as there may be turtles with same ip-power)
  ; goal - find turtle with highest ip-power (selecting starting turtle)

  foreach sort-by [ [a b] -> [ip-power] of a > [ip-power] of b ] ip-ranges [ t ->
    ask t [

      let start-xcor xcor
      let start-ycor ycor

      ; find the nearest product
      let closest-product min-one-of other ip-ranges [distance myself]
      let closest-xcor [xcor] of closest-product
      let closest-ycor [ycor] of closest-product

      let new-dist 0
      let t-radius [radius] of t
      let closest-product-radius [radius] of closest-product

      ; calculate distance between two products
      set new-dist calculate-dist closest-xcor start-xcor closest-ycor start-ycor

      ; check if two products' IP is overlapping, don't stop until no longer overlapping
      if ( t-radius + closest-product-radius <= new-dist ) [

        ifelse ( [ip-power] of t > [ip-power] of closest-product) [

          ;reduce the size of the product with less ip-power
          set radius (closest-product-radius - 1)
        ][
          set radius t-radius
        ]
      ]
    ]
  ]

end

to-report calculate-dist [x1 x2 y1 y2]
  let dist ( sqrt ((x2 - x1) ^ 2 + (y2 - y1) ^ 2) )
  report dist
end

to update-ip-range
  ask ip-links [die]
  ask products [
    hatch-temp-ip-ranges 1 [
      set size (temp-radius * 2)
      ifelse is-list? color
      [set color lput transparency sublist color 0 3]
      [set color lput transparency extract-rgb color]
      __set-line-thickness 0.2
      create-ip-link-with myself
    ]
    let num-links count my-ip-links
    ask my-ip-links [
      set ip-strength 1.0 / num-links
      set ip-flow ip-strength * [value] of myself
    ]
  ]
  ask temp-ip-ranges [
    set temp-ip-power sum [ip-flow] of my-ip-links * temp-radius
  ]

end

to set-temp-ip-ranges-values
  set temp-radius [radius] of ip-ranges
end

to make-ip-range
  ask ip-links [die]
  ;; creates the ip-range with inherited characteristics of it's parent turtle
  ;; the visible parent turtle is the product
  ask products [
    hatch-ip-ranges 1 [
      set-ip-size
      ;; change the transparency color
      ifelse is-list? color
      [set color lput transparency sublist color 0 3]
      [set color lput transparency extract-rgb color]
      ;; set thickness of halo to half a patch
      __set-line-thickness 0.3
      ;; create an undirected link from the product to the halo
      create-ip-link-with myself
    ]

  ;; calculates ip potential which is based on consumer income and size of product ip
    let num-links count my-ip-links
    ask my-ip-links [
      set ip-strength 1.0 / num-links
      set ip-flow ip-strength * [value] of myself
    ]
  ]

  ask ip-ranges [
    set ip-power sum [ip-flow] of my-ip-links * radius
  ]
end

to plot-ip

  set-current-plot "ip power"
  clear-plot
  set-current-plot-pen "flow"
  set-plot-pen-interval 1
  set-plot-x-range 0 max-pxcor
  set-plot-y-range 0 max-pycor

  let sort-ip-power reverse sort [ip-power] of ip-ranges
  foreach sort-ip-power [x -> plot x]

end

to set-ip-size
  ;; set size for product ip range
  if ip-size = "constant" [
    set size constant-ip
    set radius size / 2
  ]
  if ip-size = "random" [
    set size random 20
    set radius size / 2
  ]
end

to add-product
  ;; given a set of products put a new product on the map
  ;; find patch with max revenue

  ;; new product created at [0,0]
  create-ordered-products 1 [lt 10 fd 10] ;; can set location position [fd 1 lt 2]

  ;; should be at max revenue location
  ;; steps to function

  ;; find equilibrium price
  ;; using equilibrium price find patch with max revenue

  ;; ask if a product is on this patch
  ;; if empty sprout patch
end
@#$#@#$#@
GRAPHICS-WINDOW
200
10
748
559
-1
-1
13.171
1
10
1
1
1
0
1
1
1
-20
20
-20
20
0
0
1
ticks
30.0

BUTTON
8
11
81
44
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

SLIDER
8
127
193
160
distance-weight
distance-weight
0
30
8.5
.5
1
NIL
HORIZONTAL

PLOT
10
564
217
716
product revenue
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"revenue" 1.0 1 -7500403 true "" "histogram sort [revenue] of products"

CHOOSER
8
377
146
422
price-strategy
price-strategy
"random" "constant" "economic driven"
0

CHOOSER
8
331
146
376
buy-strategy
buy-strategy
"income driven" "no limit"
0

CHOOSER
8
285
146
330
consumer-income
consumer-income
"constant" "random"
1

SLIDER
8
171
180
204
constant-income
constant-income
0
250
131.0
1
1
NIL
HORIZONTAL

BUTTON
8
478
105
511
slow reprice
ask product min [who] of products [\n  reprice-brute-force\n]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
8
58
193
91
random-dist-product-rate
random-dist-product-rate
0
0.05
0.008
0.001
1
NIL
HORIZONTAL

BUTTON
83
11
182
45
compute-revenue
compute-revenue
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
425
564
626
716
price vs revenue
price
revenue
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"p-r" 1.0 0 -16777216 true "" "plot count turtles"

SLIDER
8
205
180
238
constant-price
constant-price
0
250
73.0
1
1
NIL
HORIZONTAL

SLIDER
8
239
180
272
profit-margin
profit-margin
0
50
8.0
1
1
NIL
HORIZONTAL

OUTPUT
467
720
735
789
11

BUTTON
8
517
105
550
fast reprice
ask products with-min [revenue] [\nreprice-dichotomous\n]
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
635
684
714
717
clear output
clear-output
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
220
564
423
716
product repriced
NIL
NIL
0.0
200.0
0.0
500.0
true
false
"" ""
PENS
"pen-0" 1.0 1 -7500403 true "" ""

CHOOSER
8
423
146
468
product-place
product-place
"even disp" "random"
1

SLIDER
8
93
193
126
even-dist-product-rate
even-dist-product-rate
.02
1
0.15
.01
1
NIL
HORIZONTAL

MONITOR
14
720
97
765
Mean Revenue
mean [revenue] of products
2
1
11

MONITOR
99
720
176
765
Max Revenue
max [revenue] of products
1
1
11

MONITOR
178
720
267
765
STD of Revenue
standard-deviation [revenue] of products
2
1
11

MONITOR
269
720
333
765
Mean Price
mean [price] of products
2
1
11

MONITOR
335
720
393
765
Max Price
max [price] of products
2
1
11

MONITOR
395
720
465
765
STD of Price
standard-deviation [price] of products
2
1
11

MONITOR
634
565
695
610
# of Firms
count products
0
1
11

MONITOR
635
613
729
658
Firms w/ Min Rev
count products with-min [revenue]
0
1
11

MONITOR
698
565
748
610
Min Rev
min [revenue] of products
2
1
11

SLIDER
759
55
931
88
constant-ip
constant-ip
0
20
2.5
.5
1
NIL
HORIZONTAL

CHOOSER
759
11
892
56
ip-size
ip-size
"constant" "random"
1

BUTTON
758
151
864
184
Show IP Area
make-ip-range
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
760
96
932
129
transparency
transparency
0
100
45.0
1
1
NIL
HORIZONTAL

BUTTON
759
193
864
226
Clear IP Area
ask ip-ranges [die]
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
759
233
826
266
Plot IP
plot-ip
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
760
273
852
306
IP Interact
ip-interact
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
760
314
960
464
ip power
products
weight of ip
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"flow" 1.0 1 -16777216 true "" ""

BUTTON
762
477
883
510
NIL
update-ip-range
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

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

thin ring
false
0
Circle -7500403 false true 105 90 0
Circle -7500403 false true 30 30 240
Circle -7500403 false true 27 27 246
Circle -7500403 false true 30 30 240
Circle -7500403 false true 27 27 246

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
NetLogo 6.2.0
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
