#!/bin/bash

# Originally for Nintendo DS roms
# Trims sparse padding off the tail of a file


if [ ! -d "trimmed" ]
then
	mkdir "trimmed"
fi

size_original=0
size_trimmed=0
num_trimmed=0
num_failed=0

for f in *.nds
do
	ndstrim "$f" "trimmed/$f"
	num_trimmed=$(($num_trimmed + 1))
	if [ -f "trimmed/$f" ]
	then
		size_original=$(($size_original + `du -b "$f" | cut -d'	' -f1`))
		size_trimmed=$(($size_trimmed + `du -b "trimmed/$f" | cut -d'	' -f1`))
	else
		num_failed=$(($num_failed + 1))
	fi
done

echo "Trimmed $num_trimmed roms ($num_failed failed)"
echo "Original size: $size_original bytes ($(($size_original/1000000)) MB)"
echo "Trimmed size: $size_trimmed bytes ($(($size_trimmed/1000000)) MB)"
echo "Saved size: $(($size_original - $size_trimmed)) bytes ($((($size_original - $size_trimmed)/1000000)) MB)"

