#!/bin/bash

sed 's!http[s]\?://\S*!URL!g' $1 > $1.noURL.txt
