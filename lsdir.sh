#!/bin/bash

# Author: Andrew Howard

# Work in progresss

DIR=$1
NUMDIRS=$(( `echo $DIR | sed 's_/_\n_g' | wc -l` - 1 ))


