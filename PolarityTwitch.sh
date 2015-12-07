#costants
input=$1
twokenizeOutput=$input.out
positiveEmotes="kappa|4head|kreygasm|elegiggle"
negativeEmotes="wutface|notlikethis|failfish|biblethump|dansgame|babyrage"

#helper functions
function CheckFile {
if [ ! -f $1 ]; then
    echo "File not found!"
    exit
fi
}

function Tokenizer
{
#Tokenize and clean the input
echo "Start Tokenizing using twokenize"
python twokenize.py $input
CheckFile $twokenizeOutput

echo "Substituting URLs with URL Token and removing useless spaces"
sed 's!http[s]\?://\S*!URL!g' $twokenizeOutput \
| perl -ne 's/(?<=(?<!\pL)\pL) (?=\pL(?!\pL))//g; print;' $input.tmp

echo "Removing lines with less than 4 tokens"
awk '{if(NF>4) print tolower($0);}' $input.tmp > $input

echo "Cleanup"
rm $twokenizeOutput $input.tmp
}

function ProcessPosNegFiles
{
CheckFile $1

echo "Generating positive file"
grep -E -i $positiveEmotes $1 > all.pos
echo "Generating negative file"
grep -E -i $negativeEmotes $1 > all.neg

posToDelete=`echo $positiveEmotes | sed 's:|://gI;s/:g'`
posToDelete="s/$posToDelete//gI;"
negToDelete=`echo $negativeEmotes | sed 's:|://gI;s/:g'`
negToDelete="s/$negToDelete//gI;"

echo "Removing emoticons from negative and positive files"
sed -e -i $posToDelete all.pos
sed -e -i $negToDelete all.neg

echo "Removing empty lines"
sed -e -i "s/  \+/ /g" all.pos
sed -e -i '/^\s*$/d' all.pos
sed -e -i "s/  \+/ /g" all.neg
sed -e -i '/^\s*$/d' all.neg
}

function RnnlmExec
{
shuf -n 12500 $1 > train-neg.txt
shuf -n 12500 $2 > train-pos.txt
shuf -n 25000 $1 > test-pos.txt
shuf -n 25000 $2 > test-neg.txt

echo "Training positive file"
head train-pos.txt -n 12300 > train
tail train-pos.txt -n 200 > valid
rnnlm -rnnlm model-pos -train train -valid valid -hidden 50 -direct-order 3 -direct 200 -class 100 -debug 2 -bptt 4 -bptt-block 10 -binary

echo "Training negative file"
head train-neg.txt -n 12300 > train
tail train-neg.txt -n 200 > valid
rnnlm -rnnlm model-neg -train train -valid valid -hidden 50 -direct-order 3 -direct 200 -class 100 -debug 2 -bptt 4 -bptt-block 10 -binary

echo "Running test"
cat test-pos.txt test-neg.txt > test.txt
#I don't know why but rnnlm needs the corpus with lines number
awk 'BEGIN{a=0;}{print a " " $0; a++;}' < test.txt > test-id.txt
rnnlm -rnnlm model-pos -test test-id.txt -debug 0 -nbest > model-pos-score
rnnlm -rnnlm model-neg -test test-id.txt -debug 0 -nbest > model-neg-score
echo "Writing result to RNNLM-SCORE"
paste model-pos-score model-neg-score | awk '{print $1 " " $2 " " $1/$2;}' > RNNLM-SCORE

echo "clean up"
rm train valid model-pos-score model-neg-score test.txt test-pos.txt test-neg.txt
rm train-neg.txt train-pos.txt
}

#MAIN PROGRAM START
while [[ $# > 1 ]]
do
key="$1"
case $key in
    -s|--steps)
    STEPS="$2"
    shift
    ;;
    *)
            # unknown option
    ;;
esac
shift
done

echo $STEPS



