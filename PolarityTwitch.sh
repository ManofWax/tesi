#costants
positiveEmotes="kappa|4head|kreygasm|elegiggle|kappapride|kreygasm|heyguys|anele"
negativeEmotes="residentsleeper|pjsalt|wutface|notlikethis|failfish|biblethump|dansgame|babyrage"
ALLPOSFILE="all.pos"
ALLNEGFILE="all.neg"
NEUTRALFILE="all.neu"
SENTENCEVECTORS="sentence_vector.txt"
TRAININGSIZE=12500
TESTSIZE=25000
PROCNUMBER=`cat /proc/cpuinfo | awk '/^processor/{print $3}' | tail -1`

#helper functions
function CheckFile {
if [ ! -f $1 ]; then
    echo "File not found!"
    exit
fi
}

function Tokenizer
{
local twokenizeOutput=$1.out
local numberOfLines=`wc -l < $1`
local linesSplit=$(($numberOfLines / $PROCNUMBER))

echo "The file contains $numberOfLines, splitting $PROCNUMBER files of $numberofLines lines"
split -l $linesSplit $1 $1.split.
echo "Launching $PROCNUMBER instances of twokenize."
echo "It will take a lot of time don't worry"
for i in `ls *.split.*`; do
    python twokenize.py $i &
done
wait

echo "Merging all files"
cat *.out > $twokenizeOutput
CheckFile $twokenizeOutput

echo "Substituting URLs with URL Token and removing useless spaces"
sed 's!http[s]\?://\S*!URL!g' $twokenizeOutput \
| perl -ne 's/(?<=(?<!\pL)\pL) (?=\pL(?!\pL))//g; print;' > $1.tmp

echo "Removing lines with less than 4 tokens"
awk '{if(NF>4) print tolower($0);}' $1.tmp > $1

echo "Cleanup"
rm $twokenizeOutput $1.tmp *.split.*
}

function ProcessPosNegFiles
{
CheckFile $1

echo "Generating positive file"
grep -E -i $positiveEmotes $1 > $ALLPOSFILE
echo "Generating negative file"
grep -E -i $negativeEmotes $1 > $ALLNEGFILE
grep -E -i -v "$positiveEmotes|$negativeEmotes" $1 > $NEUTRALFILE

posToDelete=`echo $positiveEmotes | sed 's:|://gI;s/:g'`
posToDelete="s/$posToDelete//gI"
negToDelete=`echo $negativeEmotes | sed 's:|://gI;s/:g'`
negToDelete="s/$negToDelete//gI"

echo "Removing emoticons from negative and positive files"
sed -i -e $posToDelete $ALLPOSFILE
sed -i -e $negToDelete $ALLNEGFILE

echo "Removing empty lines"
sed -i -e "s/  \+/ /g" $ALLPOSFILE
sed -i -e '/^\s*$/d' $ALLPOSFILE
sed -i -e "s/  \+/ /g" $ALLNEGFILE
sed -i -e '/^\s*$/d' $ALLNEGFILE
sed -i -e "s/  \+/ /g" $NEUTRALFILE
sed -i -e '/^\s*$/d' $NEUTRALFILE
}

function RnnlmExec
{
shuf -n 12500 $2 > train-neg.txt
shuf -n 12500 $1 > train-pos.txt
shuf -n 25000 $2 > test-neg.txt
shuf -n 25000 $1 > test-pos.txt

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

function Word2VecExec
{
CheckFile $1
CheckFile $2
CheckFile $3

echo "Merging pos, neg and neutral file"
cat $1 $2 $3 | awk 'BEGIN{a=0;}{print "_*" a " " $0; a++;}' > vec-id.txt

echo "Start computating Vectors"
time ./word2vec -train vec-id.txt -output vectors.txt -cbow 0 -size 100 -window 10 -negative 5 -hs 0 -sample 1e-4 -threads 40 -binary 0 -iter 20 -min-count 1 -sentence-vectors 1

echo "Keeping only sentence vectors"
grep '_\*' vectors.txt > sentence_vectors.txt
rm vectors.txt
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
    -i|--inputFile)
    INPUT="$2"
    shift
    ;;
    -t|--training)
    TRAININGSIZETMP="$2"
    shift
    ;;
    -tt|--test)
    TESTSIZETMP="$2"
    shift
    ;;
    *)
            # unknown option
    ;;
esac
shift
done

if [ -n $TRAININGSIZETMP ]; then
    TRAININGSIZE=$TRAININGSIZETMP
fi
if [ -n $TESTSIZETMP ]; then
    TESTSIZE=$TESTSIZETMP
fi

if [ -z $STEPS ]; then
    echo "Shitty script fuck you. Usage:"
    echo "-s --steps: set the step starting point"
    echo "  -s 0    do every step"
    echo "  -s 1    Tokenization and file cleanup"
    echo "  -s 2    Split the corpus in pos, neg and neutral files"
    echo "  -s 3    Calculate paragraph vector. It will take a lot of time and a lot of memory"
    echo "  -s 9    do steps 1,2,3"
    echo "  -s 10   Rnnlm train and test"
    echo "  -s 11   Sentence vectors/liblinear train and test"
    echo "  -s 12   Process result files and output accurancy"
    echo "-i --input: input text file. In step -s 1 IT WILL BE OVERWRITTEN"
else
    case $STEPS in
        1)
        Tokenizer $INPUT
        ;;
        2)
        ProcessPosNegFiles $INPUT
        ;;
        3)
        Word2VecExec $ALLPOSFILE $ALLNEGFILE $NEUTRALFILE
        ;;
        9)
        Tokenizer $INPUT
        ProcessPosNegFiles $INPUT
        Word2VecExec $ALLPOSFILE $ALLNEGFILE $NEUTRALFILE      
        ;;
        10) RnnlmExec $ALLPOSFILE $ALLNEGFILE
        ;;
        *)
        #doall
        ;;
    esac 
fi
