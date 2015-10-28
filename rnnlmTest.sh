corpus=all_grt1.txt
posNegDir=PosNeg
mkdir $posNegDir

grep -i "kappa" $corpus > $posNegDir/kappa.pos
grep -i "4head" $corpus > $posNegDir/4head.pos
grep -i "kreygasm" $corpus > $posNegDir/kreygasm.pos
grep -i "elegiggle" $corpus > $posNegDir/eleg.pos
grep -i "wutface" $corpus > $posNegDir/wutface.neg
grep -i "notlikethis" $corpus > $posNegDir/notlike.neg
grep -i "failfish" $corpus > $posNegDir/fail.neg
grep -i "biblethump" $corpus > $posNegDir/biblethump.neg
grep -i "dansgame" $corpus > $posNegDir/dans.neg
grep -i "babyrage" $corpus > $posNegDir/baby.neg

cd $posNegDir
cat *.pos > all_pos.txt
cat *.neg > all_neg.txt
shuf -n 12500 all_neg.txt > train-neg.txt
shuf -n 12500 all_pos.txt > train-pos.txt
shuf -n 25000 all_pos.txt > test-pos.txt
shuf -n 25000 all_neg.txt > test-neg.txt

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
  if ($3<1) if (cn<100000) corr++; \
  if ($3>1) if (cn>=100000) corr++; \
  cn++; \
} \
END{print "RNNLM accuracy: " corr/cn*100 "%";}'
