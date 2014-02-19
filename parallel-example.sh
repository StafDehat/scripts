#!/bin/bash

prog1 () { echo Program 1; }
prog2 () { echo Program 2; }
prog3 () { echo Program 3; }
prog4 () { echo Program 4; }

prog1 > /tmp/prog1out & pid1=$!
prog2 > /tmp/prog2out & pid2=$!
prog3 > /tmp/prog3out & pid3=$!
prog4 > /tmp/prog4out & pid4=$!

wait $pid1 $pid2 $pid3 $pid4

cat /tmp/prog[1-4]out

