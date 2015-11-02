posFile=$1
negFile=$2

mkdir "${posFile%.*}VS${negFile%.*}"
cd "${posFile%.*}VS${negFile%.*}"

shuf -n 12500 ../$negFile > train-neg.txt
shuf -n 25000 ../$negFile > test-neg.txt
shuf -n 12500 ../$posFile > train-pos.txt
shuf -n 25000 ../$posFile > test-pos.txt

head train-pos.txt -n 12300 > train
tail train-pos.txt -n 200 > valid
rnnlm -rnnlm model-pos -train train -valid valid -hidden 50 -direct-order 3 -direct 200 -class 100 -debug 2 -bptt 4 -bptt-block 10 -binary

head train-neg.txt -n 12300 > train
tail train-neg.txt -n 200 > valid
rnnlm -rnnlm model-neg -train train -valid valid -hidden 50 -direct-order 3 -direct 200 -class 100 -debug 2 -bptt 4 -bptt-block 10 -binary

cat test-pos.txt test-neg.txt > test.txt
#I don't know why but rnnlm needs the corpus with lines number
awk 'BEGIN{a=0;}{print a " " $0; a++;}' < test.txt > test-id.txt
rnnlm -rnnlm model-pos -test test-id.txt -debug 0 -nbest > model-pos-score
rnnlm -rnnlm model-neg -test test-id.txt -debug 0 -nbest > model-neg-score
paste model-pos-score model-neg-score | awk '{print $1 " " $2 " " $1/$2;}' > RNNLM-SCORE

cat RNNLM-SCORE | awk ' \
BEGIN{cn=0; corr=0;} \
{ \
  if ($3<1) if (cn<25000) corr++; \
  if ($3>1) if (cn>=25000) corr++; \
  cn++; \
} \
END{print "RNNLM accuracy: " corr/cn*100 "%";}' > RESULT.TXT

rm *.txt
rm model*
