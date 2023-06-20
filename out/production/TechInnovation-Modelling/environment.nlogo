globals [
  lifetimes  ; A list of lists, one for each model that existed during the run,
             ; used to plot a horizontal line from (quality, x1) to (quality, x2) for each model.
  ND
  totalModels
  this-mean
  rankedFirmsQual
  num-consumers
  totalProfit
  leastQualList ; list containing the lowest quality that is not acceptable even if it's free
  leastQual
  maxFeasibleQual
  newQualList ;list containing the qualities of new intro; with item 0 being the latest addition to the market
  recycle
  landfill
  this-max
]

breed [brands brand]
breed [models model]

brands-own [estProfit testQuality testPrice projProfit inv_QualCompR inv_QualCompL whoCR whoCL]

models-own [quality price tempPrice searchedPatches qualCompetitorRight qualCompetitorLeft neighborR neighborL
  priceCompetitorRight priceCompetitorLeft qualGreater qualLess optimalPrice newProfit allModels-Me canni? exitProfit noDemand when-born]

patches-own [cWTP greenness CS envirUtil currCS searchedModels MRconsumerSurplus]

to setup
   ;; (for this model to work with NetLogo's new plotting features,
  ;; __clear-all-and-reset-ticks should be replaced with clear-all at
  ;; the beginning of your setup procedure and reset-ticks at the end
  ;; of the procedure.)
  __clear-all-and-reset-ticks

  random-seed this-seed ;sets the seed of the pseudo-random number generator

  set newQualList [] ;initialize list containing the qualities of new introductions

  set lifetimes [] ; Initialize as an empty list

  create-brands 4 [
    hide-turtle
  ]

  ask brand 0 [
    set color 105
    hatch-models 1 [
      show-turtle
      set quality 20
      set size 1.2
      set when-born ticks
      setxy random-xcor random-ycor]; blue brand
  ]

  ask brand 1 [
    set color 25
    hatch-models 1 [
      show-turtle
      set quality 11
      set size 1.2
      set when-born ticks
      setxy random-xcor random-ycor]; orange brand
  ]

  ask brand 2 [
    set color red
    hatch-models 1 [
      show-turtle
      set quality 6
      set size 1.2
      set when-born ticks
      setxy random-xcor random-ycor]; red brand
  ]

  ask brand 3 [
    set color 135
    hatch-models 1 [
      show-turtle
      set quality 6
      set size 1.2
      set when-born ticks
      setxy random-xcor random-ycor]; pink brand
  ]

  ask models [
    set newQualList fput quality newQualList
    set price  sqrt(quality)
  ]

  set num-consumers 1000

  ask patches [
    set cWTP 1 + 2 * distancexy min-pxcor pycor
    set greenness (1 + distancexy pxcor min-pycor)
    set pcolor scale-color green greenness 0 55
    calculateCS
  ]

  set totalModels 4 ;set to initial number of models at the start
  set this-mean (sum ([quality] of models) / totalModels)

  set this-max max [quality] of models

end

to calcPrice  ;model procedure

              ; if the list qualLess is empty, set priceCompetitorLeft to zero because the quality would be zero.
              ; set qualCompetitorLeft to quality of model with the first quality just less than mine.
  ifelse length qualLess = 0
    [ set qualCompetitorLeft 0
      set priceCompetitorLeft 0
      set neighborL -1]
    [ set qualCompetitorLeft [quality] of item 0 qualLess
      set priceCompetitorLeft [price] of item 0 qualLess
      set neighborL [color] of item 0 qualLess]

  ; set qualCompetitorRight to quality of model with the first quality just greater than mine.
  ; if the list qualGreater is empty, do not set anything to qualCompetitorRight,
  ; instead use another equation to calculate price
  ifelse length qualGreater != 0
    [ set qualCompetitorRight [quality] of item 0 qualGreater
      set priceCompetitorRight [price] of item 0 qualGreater
      set neighborR [color] of item 0 qualGreater]
    [ set qualCompetitorRight (qualCompetitorLeft - 1) ;i.e. competitor right is no one, it's infinity but tag it as -1
      set neighborR -2
    ]


  ; the price equation if my quality is sandwiched between 2 other qualities.
  ifelse length qualGreater != 0 [
    set optimalPrice (
      1 / 2 * ((priceCompetitorRight * qualCompetitorLeft -
        priceCompetitorLeft * qualCompetitorRight +
        priceCompetitorLeft * quality -
        priceCompetitorRight * quality) / (qualCompetitorLeft -
      qualCompetitorRight) + 1 / (1 + ticks) + (10 * quality ^ 2) / (
      10 * quality + ticks))
      )
  ]

  ; the price equation if my quality is at the leading edge.
  [ ;show "calc as qualLeader"
    set optimalPrice (
      1 / 2 * (priceCompetitorLeft + (max [cWTP] of patches) * (-1 * qualCompetitorLeft + quality) +
        1 / (1 + ticks) + (10 * quality ^ 2) / (10 * quality + ticks))
      )
  ]

  ;    show word "Q: " quality
  ;    show word "QR: " qualCompetitorRight
  ;    show word "QL: " qualCompetitorLeft
  ;    show word "PR: " priceCompetitorRight
  ;    show word "PL: " priceCompetitorLeft
  ;    show word "OP: " optimalPrice

  ;  if optimalPrice < 0 [stop]

  ifelse any? other models with [quality = [quality] of myself][
    ifelse optimalPrice > min [price] of (other models with [quality = [quality] of myself]) ; then undercut your competitor by pricing sligtly below its price, but above MC
      [set tempPrice (min [price] of (other models with [quality = [quality] of myself])
        - random-float ((min [price] of (other models with [quality = [quality] of myself])) - (quality ^ 2 /(quality + 1 / 10 * ticks) + 1 / (ticks + 1))))

      ;      show word "min other price: " min [price] of (other models with [quality = [quality] of myself])
      ;      show word "MC: " ((quality) ^ 2 /((quality) ^ 2 + (techRate * ticks)))
      ;      show word "undercut: " random-float ((min [price] of (other models with [quality = [quality] of myself])) - (quality) ^ 2 /((quality) ^ 2 + (techRate * ticks)))
      ;      show word "tempPrice: " tempPrice
      ]
      [set tempPrice optimalPrice]
  ]
  [set tempPrice optimalPrice] ;if no other model with quality equal to my own, set tempPrice to optimalPrice

end


to calculateCS ;patch procedure

  set searchedModels n-of (1 + random count models) models ;consumers only look for best return after searching a subset of ALL the phones available
                                                           ;select the model (from the subset of models searched, searchedModels) that gives a consumer the most CS

  let modelGivingMaxCS (max-one-of searchedModels [[cWTP] of myself * quality - (price + depositFee)]) ;;IMPORTANT: If you make any changes here, please edit
                                                                                                       ;;MRconsumerSurplus in MarketResearch Procedure

  set CS (cWTP * [quality] of modelGivingMaxCS - [price] of modelGivingMaxCS - depositFee)

  ;;if another sampled phone gives more CS, then change phone.
  if CS > currCS [

    set plabel [who] of modelGivingMaxCS
    set currCS (CS + depositFee)

    set envirUtil (greenness * (1 + depositFee) - nuisanceCost)

    ifelse envirUtil > 0
    [set recycle (recycle + num-consumers)]
    [set landfill (landfill + num-consumers)]
  ]

end

to innovate ;brand procedure

  hatch-models 1 [
    set when-born ticks
    hide-turtle
    set quality (1 + random (maxFeasibleQual - leastQual) + leastQual)

    updateQualLists models
    calcPrice
    marketResearch

   ; show word "newQual: " quality
   ; show word "price: " tempPrice

    set price tempPrice

    let this-who who
    let this-qual quality
    ; show word "this-qual: " quality
    ; show word "NP: " newProfit
    let this-newProfit newProfit
    ; show word "this-NP: " newProfit
    ; show word "tempPrice: " tempPrice
    let this-tempPrice tempPrice
    ; show word "this-tempPrice: " tempPrice
    let this-QCR qualCompetitorRight
    let this-QCL qualCompetitorLeft
    ;     show "Im here"
    ;     show word "quality: " quality
    ;     show word "price: " tempPrice
    ;     show word "newProfit: " newProfit

    let this-whoCL neighborL
    let this-whoCR neighborR


    ask other models with [color = [color] of myself] [
      updateQualLists models
      if ((length qualGreater != 0) and ([who] of item 0 qualGreater = this-who)) or ((length qualLess != 0) and ([who] of item 0 qualLess = this-who))[
        calcPrice
        marketResearch]
    ]

    ;ask models with [color = [color] of myself] [show newProfit]

    ask myself[
      set estProfit sum [newProfit] of models with [color = [color] of myself]
    ]

    ask myself [
      ;   show who
      set testQuality this-qual
      set projProfit estProfit
      set testPrice this-tempPrice
      set inv_QualCompR this-QCR
      set inv_QualCompL this-QCL
      set whoCR this-whoCR
      set whoCL this-whoCL
    ]


    ifelse [estProfit] of myself > entryCost [
      set newQualList fput this-qual newQualList
      show-turtle
      setxy random-xcor random-ycor

      ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
      ;; To update the mean qualities of all phones since the beginning of times;;
      ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
      ;      show word "totalModels: " totalModels
      ;      show word "new Qual: " quality
      set this-mean ((this-mean * totalModels + quality) / (totalModels + 1))
      ;      show word "MEAN: " this-mean
      set totalModels totalModels + 1

    ]
    [die] ; if estimate profit from new model does not reap a profit that exceeds FC,
          ; then do not release model into market [fails during marketResearch stage].
  ]

end

to go

  ask brands [
    set testQuality 0
    set testPrice 0
    set projProfit 0
    set inv_QualCompR 0
    set inv_QualCompL 0
    set whoCR 0
    set whoCL 0
  ]

  ask models [
    updateQualLists models
    calcPrice]
  ask models [set price tempPrice
  ;  show price
    ] ; simultaneous price decisions [2 stage game]


  ask patches [calculateCS]

  lowerBoundQual ; determines the lowest quality a consumer is willing to buy if the model sells for free
  ask models [
    if quality < leastQual [
      record-lifetime
      die]
    if count patches with [plabel = [who] of myself] = 0 [set noDemand noDemand + 1]
    if noDemand = 1000 [ set ND ND + 1
      record-lifetime
      die]
  ]

  set maxFeasibleQual (this-max + 100)

  ask brands [
    let this-random random-float 1
    if this-random < (1 / 50)
    [innovate]]

;  show word "time: " ticks
;  show word "ThisMax: " this-max
;  show word "max: " max [quality] of models

  if max [quality] of models > this-max [set this-max max [quality] of models]

  labelCanniModels

  ask brands[
    if any? (models with [color = [color] of myself]) with [canni? = true] [
      checkExit
    ]
  ]
  ask models [
    set exitProfit 0
    set canni? false]

  tick
;  show word "maxFeasible: " maxFeasibleQual
  do-plot
  if ticks = 20001 [
    ask models [ record-lifetime ]
    stop]

end

to do-plot
  set-current-plot "number of phone-variety"
  set-current-plot-pen "Blue"
  plot count models with [color = 105]
  set-current-plot-pen "Orange"
  plot count models with [color = 25]
  set-current-plot-pen "Red"
  plot count models with [color = red]
  set-current-plot-pen "Pink"
  plot count models with [color = 135]

  set-current-plot "mean of quality"
  plot this-mean

  set-current-plot "Num of phones landfilled"
  plot landfill

  set-current-plot "Num of phones recycled"
  plot recycle

  set-current-plot "quality frontier"
  set-current-plot-pen "new quality"
  plot item 0 newQualList
  set-current-plot-pen "max feasible quality"
  plot (maxFeasibleQual)
  set-current-plot-pen "max quality"
  plot max [quality] of models
  set-current-plot-pen "least profitable quality"
  plot leastQual
  set-current-plot-pen "min quality"
  plot min [quality] of models

  set-current-plot "Blue: innovation quality"
  set-current-plot-pen "maxFeasible"
  plot (maxFeasibleQual)
  set-current-plot-pen "minProfitable"
  plot leastQual
  set-current-plot-pen "Blue"
  plot [testQuality] of one-of brands with  [color = 105]

  set-current-plot "Orange: innovation quality"
  set-current-plot-pen "maxFeasible"
  plot (maxFeasibleQual)
  set-current-plot-pen "minProfitable"
  plot leastQual
  set-current-plot-pen "Orange"
  plot [testQuality] of one-of brands with  [color = 25]

  set-current-plot "Red: innovation quality"
  set-current-plot-pen "maxFeasible"
  plot (maxFeasibleQual)
  set-current-plot-pen "minProfitable"
  plot leastQual
  set-current-plot-pen "Red"
  plot [testQuality] of one-of brands with  [color = red]

  set-current-plot "Pink: innovation quality"
  set-current-plot-pen "maxFeasible"
  plot (maxFeasibleQual)
  set-current-plot-pen "minProfitable"
  plot leastQual
  set-current-plot-pen "Pink"
  plot [testQuality] of one-of brands with  [color = 135]


  set-current-plot "Blue: innovation price"
  set-current-plot-pen "Blue"
  plot [testPrice] of one-of brands with  [color = 105]

  set-current-plot "Orange: innovation price"
  set-current-plot-pen "Orange"
  plot [testPrice] of one-of brands with  [color = 25]

  set-current-plot "Red: innovation price"
  set-current-plot-pen "Red"
  plot [testPrice] of one-of brands with  [color = red]

  set-current-plot "Pink: innovation price"
  set-current-plot-pen "Pink"
  plot [testPrice] of one-of brands with  [color = 135]


  set-current-plot "innovation profit"
  set-current-plot-pen "FC"
  plot entryCost
  set-current-plot-pen "Blue"
  plot [projProfit] of one-of brands with  [color = 105]
  set-current-plot-pen "Orange"
  plot [projProfit] of one-of brands with  [color = 25]
  set-current-plot-pen "Red"
  plot [projProfit] of one-of brands with  [color = red]
  set-current-plot-pen "Pink"
  plot [projProfit] of one-of brands with  [color = 135]

end

to marketResearch ;model procedure

                  ;model performs market research on a subset of all consumers available, then scale this searched region to fit the whole world
  set searchedPatches n-of ((random 300) + 1) patches
  ask searchedPatches [
    set MRconsumerSurplus (cWTP * [quality] of myself  - ([tempPrice] of myself + depositFee))
 ;   show word "MR_CS: " MRconsumerSurplus
 ;   show word "currCS: " currCS
    ;  if  MRconsumerSurplus > currCS [show "true" show word "MRCS: " MRconsumerSurplus  show word "currCS: " currCS]
  ]

  ;show word "numCwMRCS: " count searchedPatches with [MRconsumerSurplus > currCS]

  let consumersWillingToImprove ((count searchedPatches with [MRconsumerSurplus > currCS]) * ((count patches) / count searchedPatches) * num-consumers)

  set newProfit (tempPrice - ( quality ^ 2 / (quality + 1 / 10 * ticks) + 1 / (ticks + 1))) * consumersWillingToImprove

end


to checkExit ; brand procedure

  set totalProfit 0

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;;;;;;;;;;;;;;;;;;;Estimate profit if configuration of models offered is unchanged;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  ask models with [color = [color] of myself][
    updateQualLists (models)
    calcPrice
    ;    show word "tempPrice: " tempPrice
    marketResearch
    ;    show word "newProfit: " newProfit
    set totalProfit totalProfit + newProfit
  ]

  ; show word "TP: " totalProfit

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;;;;;;;;;;;;;;;;;;;Estimate profit if removed one product at a time;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  ask models with [color = [color] of myself] [
    if canni? = true[
      set allModels-Me (other models) ;agentset of ALL models minus myself

                                      ; show word "AM-M: " sort-by [[quality] of ?1 < [quality] of ?2] other models

      let otherModelsSameBrand other models with [color = [color] of myself] ;agentset of models from same brand minus myself

                                                                             ; show word "OMSB: " [who] of otherModelsSameBrand

      if count otherModelsSameBrand != 0 [
        ask otherModelsSameBrand
        [
          ;   show word "allModels-Me: " [who] of [allModels-Me] of myself
          updateQualLists [allModels-Me] of myself
          calcPrice
          marketResearch
        ]
      ]

      set exitProfit sum [newProfit] of otherModelsSameBrand
      ;     show word "EP: " exitProfit
    ]
  ]

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;;;;;;;;;;;;;;;;;;;Check condition for exit due to cannibalization;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  let modelwithMaxExitProfit max-one-of models with [color = [color] of myself] [exitProfit]
  ; show word "MM: " modelwithMaxExitProfit
  ; show word "MwMEP: " [exitProfit] of modelwithMaxExitProfit

  if [exitProfit] of modelwithMaxExitProfit > totalProfit [
    ; show word "MwMEP: " [exitProfit] of modelwithMaxExitProfit
    ; show word "TP: " totalProfit
    ask modelwithMaxExitProfit [
      ; show "LALALA"
      record-lifetime
      die]
  ]


end

to updateQualLists [this-agentset]
  set qualGreater (sort-by [ [?1 ?2] -> [quality] of ?1 < [quality] of ?2 ] other this-agentset with [quality > [quality] of myself])
  ;  ifelse length qualGreater != 0 [show word "right: " item 0 qualGreater] [show "EMPTY"]
  set qualLess (sort-by [ [?1 ?2] -> [quality] of ?1 > [quality] of ?2 ] other this-agentset with [quality < [quality] of myself])
  ;  ifelse length qualLess != 0 [show word "left: " item 0 qualLess] [show "EMPTY"]
end

to labelCanniModels ;observer procedure

  set rankedFirmsQual sort-by [ [?1 ?2] -> [quality] of ?1 < [quality] of ?2 ] models

  ; show rankedFirmsQual

  ask models [
    if (1 + (position self rankedFirmsQual) = length  rankedFirmsQual
      or [color] of item (1 + (position self rankedFirmsQual)) rankedFirmsQual = color)
    and (-1 + (position self rankedFirmsQual) < 0
      or [color] of item (-1 + (position self rankedFirmsQual)) rankedFirmsQual = color)
    [set canni? true
      ;     show "cannibalization?"
    ]
  ]
end

to lowerBoundQual

  set leastQualList []

  foreach sort patches with [pycor = min-pycor][ ?1 ->
    ask ?1 [
      let modelMaxCS max-one-of models [quality * ([cWTP] of myself) - price] ; the max CS patch is receiving
                                                                              ; show modelMaxCS
      set leastQualList lput ((1 / cWTP) * ([quality] of modelMaxCS * cWTP - [price] of modelMaxCS)) leastQualList] ; the quality that will give a consumer, for a price of zero,
                                                                                                                    ; the same CS as maxCS
  ]

  ifelse min leastQualList < 0
  [set leastQual 0]
  [set leastQual min leastQualList] ; from the list of qualities, identify the lowest quality
                                    ;show word "LBQ " lowerBndQual

end

;call this procedure as the model is about to die (and also see below)

to record-lifetime ; turtle (model) procedure
  set lifetimes fput (list quality color when-born ticks) lifetimes
end

;;;;;;:::::::::::::::::::::;;;;;;:::::::::::::::::::::;;;;;;:::::::::::::::::::::;
;;;;;;:::::::::::::::::::::To be used in behavior space;;;;;;:::::::::::::::::::::
;;;;;;:::::::::::::::::::::;;;;;;:::::::::::::::::::::;;;;;;:::::::::::::::::::::;

to-report priceOfModel [listModel]
  report map [ ?1 -> [price] of ?1 ] listModel
end

to-report brandOfModel [listModel]
  report map [ ?1 -> [color] of ?1 ] listModel
end

to-report qualOfModel [listModel]
  report map [ ?1 -> [quality] of ?1 ] listModel
end
@#$#@#$#@
GRAPHICS-WINDOW
265
31
687
454
-1
-1
8.12
1
10
1
1
1
0
0
0
1
-25
25
-25
25
0
0
1
ticks
30.0

BUTTON
14
13
77
56
NIL
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
15
431
78
464
NIL
go
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
1122
193
1338
341
number of phone-variety
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Blue" 1.0 0 -13345367 true "" ""
"Orange" 1.0 0 -955883 true "" ""
"Red" 1.0 0 -2674135 true "" ""
"Pink" 1.0 0 -2064490 true "" ""

BUTTON
93
432
156
465
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

PLOT
1122
37
1338
187
mean of quality
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
"default" 1.0 0 -16777216 true "" ""

PLOT
695
35
895
185
Num of phones landfilled
ticks
num of phones
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

PLOT
698
194
1107
344
quality frontier
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"new quality" 1.0 0 -5825686 true "" ""
"max feasible quality" 1.0 0 -8630108 true "" ""
"max quality" 1.0 0 -13345367 true "" ""
"least profitable quality" 1.0 0 -7500403 true "" ""
"min quality" 1.0 0 -6459832 true "" ""

CHOOSER
87
12
251
57
this-seed
this-seed
-788344243
0

PLOT
698
358
1107
478
innovation profit
tick
$
0.0
500.0
0.0
1.0E7
true
true
"" ""
PENS
"Blue" 1.0 0 -13345367 true "" ""
"Orange" 1.0 0 -955883 true "" ""
"Red" 1.0 0 -2674135 true "" ""
"Pink" 1.0 0 -2064490 true "" ""
"FC" 1.0 0 -8630108 true "" ""

PLOT
13
482
312
632
Blue: innovation quality
quality
tick
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Blue" 1.0 0 -13345367 true "" ""
"maxFeasible" 1.0 0 -8630108 true "" ""
"minProfitable" 1.0 0 -7500403 true "" ""

PLOT
320
484
617
634
Orange: innovation quality
quality
tick
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Orange" 1.0 0 -955883 true "" ""
"maxFeasible" 1.0 0 -8630108 true "" ""
"minProfitable" 1.0 0 -7500403 true "" ""

PLOT
626
484
955
634
Red: innovation quality
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Red" 1.0 0 -2674135 true "" ""
"maxFeasible" 1.0 0 -8630108 true "" ""
"minProfitable" 1.0 0 -7500403 true "" ""

PLOT
968
484
1285
634
Pink: innovation quality
quality
tick
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Pink" 1.0 0 -2064490 true "" ""
"maxFeasible" 1.0 0 -8630108 true "" ""
"minProfitable" 1.0 0 -7500403 true "" ""

PLOT
13
642
310
792
Blue: innovation price
tick
price/$
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Blue" 1.0 0 -13345367 true "" ""

PLOT
317
643
617
793
Orange: innovation price
tick
price/$
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Orange" 1.0 0 -955883 true "" ""

PLOT
629
642
956
792
Red: innovation price
tick
price/$
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Red" 1.0 0 -2674135 true "" ""

PLOT
972
641
1205
791
Pink: innovation price
tick
price/$
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Pink" 1.0 0 -2064490 true "" ""

SLIDER
19
150
191
183
depositFee
depositFee
0
1000
50.0
5
1
NIL
HORIZONTAL

PLOT
910
36
1110
186
Num of phones recycled
tick
num of phones
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

SLIDER
19
109
191
142
entryCost
entryCost
1E4
1E10
1.0E9
1
1
NIL
HORIZONTAL

SLIDER
20
203
192
236
nuisanceCost
nuisanceCost
0
3500
1500.0
100
1
NIL
HORIZONTAL

@#$#@#$#@
## transfer to version 5

Previous seeds:

-1747015842698076
-6914483850117030
941921222322569
-3054451770892648
5434335010484310
-689915914826877
8890936216989741
5546126286956369
-1673555662014545
-8623851637166165
-1817866416580635
-1977607278782730
4806732351847632
3440303033756876
-2194305116546636
-8861348026984000
5961853648588596
-3651599885064267
-7844065847343183
-4865625223656543
-7440596778345283
-976124070931041
-4227199884427059
-5454330436303319
1187005401780688
-3624308862749697
3897613093544856
-1398663036359160
5829757646297413
-557024576425480

## WHAT IS IT?

This section could give a general understanding of what the model is trying to show or explain.

## HOW IT WORKS

This section could explain what rules the agents use to create the overall behavior of the model.

## HOW TO USE IT

This section could explain how to use the model, including a description of each of the items in the interface tab.

## THINGS TO NOTICE

This section could give some ideas of things for the user to notice while running the model.

## THINGS TO TRY

This section could give some ideas of things for the user to try to do (move sliders, switches, etc.) with the model.

## EXTENDING THE MODEL

This section could give some ideas of things to add or change in the procedures tab to make the model more complicated, detailed, accurate, etc.

## NETLOGO FEATURES

This section could point out any especially interesting or unusual features of NetLogo that the model makes use of, particularly in the Procedures tab.  It might also point out places where workarounds were needed because of missing features.

## RELATED MODELS

This section could give the names of models in the NetLogo Models Library or elsewhere which are of related interest.

## CREDITS AND REFERENCES

This section could contain a reference to the model's URL on the web if it has one, as well as any other necessary credits or references.
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
0
Rectangle -7500403 true true 151 225 180 285
Rectangle -7500403 true true 47 225 75 285
Rectangle -7500403 true true 15 75 210 225
Circle -7500403 true true 135 75 150
Circle -16777216 true false 165 76 116

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

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.3.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="brand_price_model" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>brandOfModel sort-by [ [?1 ?2] -&gt; [quality] of ?1 &gt; [quality] of ?2 ] models</metric>
    <metric>priceOfModel sort-by [ [?1 ?2] -&gt; [quality] of ?1 &gt; [quality] of ?2 ] models</metric>
    <metric>qualOfModel sort-by [ [?1 ?2] -&gt; [quality] of ?1 &gt; [quality] of ?2 ] models</metric>
    <enumeratedValueSet variable="techRate">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fixedCost">
      <value value="1000000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="this-seed">
      <value value="3440303033756876"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="frontier" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>item 0 newQualList</metric>
    <metric>leastQual</metric>
    <metric>min [quality] of models</metric>
    <metric>max [quality] of models</metric>
    <metric>max [quality] of models + 100</metric>
    <enumeratedValueSet variable="techRate">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="this-seed">
      <value value="-1747015842698076"/>
      <value value="-6914483850117030"/>
      <value value="941921222322569"/>
      <value value="-3054451770892648"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="FC" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>mean [quality] of models</metric>
    <enumeratedValueSet variable="fixedCost">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="this-seed">
      <value value="-1747015842698076"/>
      <value value="-6914483850117030"/>
      <value value="941921222322569"/>
      <value value="-3054451770892648"/>
      <value value="5434335010484310"/>
      <value value="-689915914826877"/>
      <value value="8890936216989741"/>
      <value value="5546126286956369"/>
      <value value="-1673555662014545"/>
      <value value="-8623851637166165"/>
      <value value="-1817866416580635"/>
      <value value="-1977607278782730"/>
      <value value="4806732351847632"/>
      <value value="3440303033756876"/>
      <value value="-2194305116546636"/>
      <value value="-8861348026984000"/>
      <value value="5961853648588596"/>
      <value value="-3651599885064267"/>
      <value value="-7844065847343183"/>
      <value value="-4865625223656543"/>
      <value value="-7440596778345283"/>
      <value value="-976124070931041"/>
      <value value="-4227199884427059"/>
      <value value="-5454330436303319"/>
      <value value="1187005401780688"/>
      <value value="-3624308862749697"/>
      <value value="3897613093544856"/>
      <value value="-1398663036359160"/>
      <value value="5829757646297413"/>
      <value value="-557024576425480"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="innovation" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>[testQuality] of brand 0</metric>
    <metric>[testQuality] of brand 1</metric>
    <metric>[testQuality] of brand 2</metric>
    <metric>[testQuality] of brand 3</metric>
    <metric>[testPrice] of brand 0</metric>
    <metric>[testPrice] of brand 1</metric>
    <metric>[testPrice] of brand 2</metric>
    <metric>[testPrice] of brand 3</metric>
    <metric>[projProfit] of brand 0</metric>
    <metric>[projProfit] of brand 1</metric>
    <metric>[projProfit] of brand 2</metric>
    <metric>[projProfit] of brand 3</metric>
    <enumeratedValueSet variable="this-seed">
      <value value="-1747015842698076"/>
      <value value="-6914483850117030"/>
      <value value="941921222322569"/>
      <value value="-3054451770892648"/>
      <value value="5434335010484310"/>
      <value value="-689915914826877"/>
      <value value="8890936216989741"/>
      <value value="5546126286956369"/>
      <value value="-1673555662014545"/>
      <value value="-8623851637166165"/>
      <value value="-1817866416580635"/>
      <value value="-1977607278782730"/>
      <value value="4806732351847632"/>
      <value value="3440303033756876"/>
      <value value="-2194305116546636"/>
      <value value="-8861348026984000"/>
      <value value="5961853648588596"/>
      <value value="-3651599885064267"/>
      <value value="-7844065847343183"/>
      <value value="-4865625223656543"/>
      <value value="-7440596778345283"/>
      <value value="-976124070931041"/>
      <value value="-4227199884427059"/>
      <value value="-5454330436303319"/>
      <value value="1187005401780688"/>
      <value value="-3624308862749697"/>
      <value value="3897613093544856"/>
      <value value="-1398663036359160"/>
      <value value="5829757646297413"/>
      <value value="-557024576425480"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fixedCost">
      <value value="100000"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="qualDist_innov" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>[inv_QualCompL] of brand 0</metric>
    <metric>[testQuality] of brand 0</metric>
    <metric>[inv_QualCompR] of brand 0</metric>
    <metric>[projProfit] of brand 0</metric>
    <metric>[inv_QualCompL] of brand 1</metric>
    <metric>[testQuality] of brand 1</metric>
    <metric>[inv_QualCompR] of brand 1</metric>
    <metric>[projProfit] of brand 1</metric>
    <metric>[inv_QualCompL] of brand 2</metric>
    <metric>[testQuality] of brand 2</metric>
    <metric>[inv_QualCompR] of brand 2</metric>
    <metric>[projProfit] of brand 2</metric>
    <metric>[inv_QualCompL] of brand 3</metric>
    <metric>[testQuality] of brand 3</metric>
    <metric>[inv_QualCompR] of brand 3</metric>
    <metric>[projProfit] of brand 3</metric>
    <metric>maxFeasibleQual</metric>
    <enumeratedValueSet variable="fixedCost">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="this-seed">
      <value value="-1747015842698076"/>
      <value value="-6914483850117030"/>
      <value value="941921222322569"/>
      <value value="-3054451770892648"/>
      <value value="5434335010484310"/>
      <value value="-689915914826877"/>
      <value value="8890936216989741"/>
      <value value="5546126286956369"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="neighbors" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>[whoCL] of brand 0</metric>
    <metric>[whoCR] of brand 0</metric>
    <metric>[projProfit] of brand 0</metric>
    <metric>[whoCL] of brand 1</metric>
    <metric>[whoCR] of brand 1</metric>
    <metric>[projProfit] of brand 1</metric>
    <metric>[whoCL] of brand 2</metric>
    <metric>[whoCR] of brand 2</metric>
    <metric>[projProfit] of brand 2</metric>
    <metric>[whoCL] of brand 3</metric>
    <metric>[whoCR] of brand 3</metric>
    <metric>[projProfit] of brand 3</metric>
    <enumeratedValueSet variable="this-seed">
      <value value="-1747015842698076"/>
      <value value="-6914483850117030"/>
      <value value="941921222322569"/>
      <value value="-3054451770892648"/>
      <value value="5434335010484310"/>
      <value value="-689915914826877"/>
      <value value="8890936216989741"/>
      <value value="5546126286956369"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fixedCost">
      <value value="100000000"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="envir" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>recycle</metric>
    <metric>landfill</metric>
    <metric>this-mean</metric>
    <enumeratedValueSet variable="this-seed">
      <value value="-1747015842698076"/>
      <value value="-6914483850117030"/>
      <value value="5434335010484310"/>
      <value value="-1977607278782730"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="depositFee">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="entryCost">
      <value value="1000000000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nuisanceCost">
      <value value="1500"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ND" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>ND</metric>
    <enumeratedValueSet variable="nuisanceCost">
      <value value="1500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="entryCost">
      <value value="1000000000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="depositFee">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="this-seed">
      <value value="-1747015842698076"/>
      <value value="-6914483850117030"/>
      <value value="941921222322569"/>
      <value value="-3054451770892648"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
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
