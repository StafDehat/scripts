#!/bin/bash

# Author: Andrew Howard


function average() {
  SUM=0
  COUNT=0
  while read LINE; do
    SUM=$( printf "%.3f" $(bc -l <<< "$SUM + $LINE" ) )
    COUNT=$(( COUNT + 1 ))
  done
  printf "%.3f\n" $(bc -l <<< "$SUM / $COUNT" )
}


# Take whitespace-separated input from either 
#   arguments or STDIN, and calculate the product.
function sum() {
  local input
  if [[ "${#}" -gt 0 ]]; then
    input=${@}
  else
    input=$( cat )
  fi
  {
    echo -n "0";
    for x in ${input}; do
      echo -n " + ${x}"
    done;
    echo;
  } | bc -l
}


# Take whitespace-separated input from either 
#   arguments or STDIN, and calculate the product.
function product() {
  local input
  if [[ "${#}" -gt 0 ]]; then
    input=${@}
  else
    input=$( cat )
  fi
  {
    echo -n "1";
    for x in ${input}; do
      echo -n " * ${x}"
    done;
    echo;
  } | bc -l
}


function sqrt() {
  echo "sqrt($1)" | bc
}


function factor() {
  n=$1
  for x in `seq 1 $(sqrt $n)`; do
    if [ $(($n % $x)) -eq 0 ]; then
      echo $x
      echo $(($n / $x))
    fi
  done | sort -nu
}


# All numbers < n with no factors in common with n
function totient() {
  n=$1
  facn=`factor $n | tail -n +2`
  totives=1
  for x in `seq 3 $(( $n - 1))`; do
    facx=`factor $x | tail -n +2`
    if [ `comm -12 <(echo "$facx") \
                   <(echo "$facn") 2>/dev/null | wc -l` -eq 0 ]; then
      totives=$(( $totives + 1 ))
    fi
  done
  echo $totives
}


function magicsquare() {
  SUM=$1

}






