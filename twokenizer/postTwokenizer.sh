#!/bin/bash

#replece urls with the string URL and with the perl magic transform "K a p p a B o y s" in "KappaBoys"
sed 's!http[s]\?://\S*!URL!g' $1 |  perl -ne 's/(?<=(?<!\pL)\pL) (?=\pL(?!\pL))//g; print;' > $1.processed.txt
