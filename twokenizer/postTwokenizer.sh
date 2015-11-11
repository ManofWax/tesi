#!/bin/bash

#replece urls with the string URL and with the perl magic transform "K a p p a B o y s" in "KappaBoys"
sed 's!http[s]\?://\S*!URL!g' $1 |  perl -ne 's/(?<=(?<!\pL)\pL) (?=\pL(?!\pL))//g; print;' > $1.processed.txt


#Remove lines with more than 3 repetition per word
#grep -P '^(?!.*?\b(\w+)\W+\g{-1}\W+\g{-1}).*' all.perl.lower.txt > 
#DISREGARD THAT IT DOESN'T WORK
