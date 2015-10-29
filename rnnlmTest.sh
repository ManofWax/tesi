corpus=all.noURL.txt
posNegDir=PosNeg
mkdir $posNegDir

awk '{if(NF>4) print $0}' $corpus > $corpus.4.txt
corpus=$corpus.4.txt

grep -E -i "kappa|4head|kreygasm|elegiggle" $corpus > $posNegDir/all.pos
grep -E -i "wutface|notlikethis|failfish|biblethump|dansgame|babyrage" $corpus > $posNegDir/all.neg

cd $posNegDir
sed -e "s/kappa//gI;s/4head//gI;s/kreygasm//gI;s/elegiggle//gI" < all.pos > all_pos_processed.txt
sed -e "s/wutface//gI;s/notlikethis//gI;s/failfish//gI;s/biblethump//gI;s/dansgame//gI;s/babyrage//gI" < all.neg > all_neg_processed.txt
shuf -n 12500 all_neg_processed.txt > train-neg.txt
shuf -n 12500 all_pos_processed.txt > train-pos.txt
shuf -n 25000 all_pos_processed.txt > test-pos.txt
shuf -n 25000 all_neg_processed.txt > test-neg.txt

head train-pos.txt -n 12300 > train
tail train-pos.txt -n 200 > valid
rnnlm -rnnlm model-pos -train train -valid valid -hidden 50 -direct-order 3 -direct 200 -class 100 -debug 2 -bptt 4 -bptt-block 10 -binary

head train-neg.txt -n 12300 > train
tail train-neg.txt -n 200 > valid
rnnlm -rnnlm model-neg -train train -valid valid -hidden 50 -direct-order 3 -direct 200 -class 100 -debug 2 -bptt 4 -bptt-block 10 -binary

cat test-pos.txt test-neg.txt > test.txt
awk 'BEGIN{a=0;}{print a " " $0; a++;}' < test.txt > test-id.txt
rnnlm -rnnlm model-pos -test test-id.txt -debug 0 -nbest > model-pos-score
rnnlm -rnnlm model-neg -test test-id.txt -debug 0 -nbest > model-neg-score
paste model-pos-score model-neg-score | awk '{print $1 " " $2 " " $1/$2;}' > ../RNNLM-SCORE
cd ..

cat RNNLM-SCORE | awk ' \
BEGIN{cn=0; corr=0;} \
{ \
  if ($3<1) if (cn<50000) corr++; \
  if ($3>1) if (cn>=50000) corr++; \
  cn++; \
} \
END{print "RNNLM accuracy: " corr/cn*100 "%";}'
