#costants
positiveEmotes="kappa|4head|kreygasm|elegiggle|kappapride|kreygasm|heyguys|anele"
negativeEmotes="babyrageresidentsleeper|pjsalt|wutface|notlikethis|failfish|biblethump|dansgame|babyrage"
ALLPOSFILE="all.pos"
ALLNEGFILE="all.neg"
NEUTRALFILE="all.neu"
SENTENCEVECTORS="sentence_vector.txt"
TRAININGSIZE=12500
TESTSIZE=25000
PROCNUMBER=`cat /proc/cpuinfo | awk '/^processor/{print $3}' | tail -1`
RNNLMBINARY="rnnlm/rnnlm"
WORD2VECBINARY="word2vec/word2vec"
LIBLINEARTRAINBINARY="liblinear/train"
LIBLINEARPREDICTBINARY="liblinear=predict"

#helper functions
function CheckFile {
if [ ! -f $1 ]; then
    echo "File not found!"
    exit
fi
}

function Build
{
echo "Compiling Rnnlm"
mkdir rnnlm
cd rnnlm
wget https://github.com/ManofWax/tesi/blob/master/Tools/rnnlm-0.4b.tgz?raw=true -O rnnlm.tgz
tar --strip-components=1 -xvf rnnlm.tgz
g++ -lm -O3 -march=native -Wall -funroll-loops -ffast-math -c rnnlmlib.cpp
g++ -lm -O3 -march=native -Wall -funroll-loops -ffast-math rnnlm.cpp rnnlmlib.o -o rnnlm
chmod +x rnnlm
cd ..

echo "Compiling word2vec with sentence vectors patch"
mkdir word2vec
cd word2vec
wget https://github.com/ManofWax/tesi/blob/master/Tools/word2vec.c?raw=true -O word2vec.c
gcc word2vec.c -o word2vec -lm -pthread -O3 -march=native -funroll-loops
chmod +x word2vec
cd ..

echo "Compiling liblinear"
mkdir liblinear
cd liblinear
wget https://github.com/ManofWax/tesi/blob/master/Tools/liblinear-2.1.tar.gz?raw=true -O liblinear.tar.gz
tar --strip-components=1 -xvf liblinear.tar.gz
make
chmod +x train
chmod +x predict
cd ..

echo "Downloading Twokenizer"
wget twokenizer -O twokenize.py
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
    python twokenize.py $i `echo $i | sed -e's/.split.//gI'`.out &
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
rm $1.tmp *.split.* *.out
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
head -n $TRAININGSIZE $1 > train-pos.txt
head -n $TRAININGSIZE $2 > train-neg.txt
tail -n $TESTSIZE $1 > test-pos.txt
tail -n $TESTSIZE $2 > test-neg.txt

head train-pos.txt -n $(($TRAININGSIZE - 200)) > train.pos
tail train-pos.txt -n 200 > valid.pos

head train-neg.txt -n $(($TRAININGSIZE - 200)) > train.neg
tail train-neg.txt -n 200 > valid.neg

echo "Running Rnnlm training"
$RNNLMBINARY -rnnlm model-pos -train train.pos -valid valid.pos -hidden 50 -direct-order 3 -direct 200 -class 100 -debug 2 -bptt 4 -bptt-block 10 -binary
$RNNLMBINARY -rnnlm model-neg -train train.neg -valid valid.neg -hidden 50 -direct-order 3 -direct 200 -class 100 -debug 2 -bptt 4 -bptt-block 10 -binary

echo "Running test"
cat test-pos.txt test-neg.txt > test.txt
#I don't know why but rnnlm needs the corpus with lines number
awk 'BEGIN{a=0;}{print a " " $0; a++;}' < test.txt > test-id.txt
$RNNLMBINARY -rnnlm model-pos -test test-id.txt -debug 0 -nbest > model-pos-score
$RNNLMBINARY -rnnlm model-neg -test test-id.txt -debug 0 -nbest > model-neg-score
echo "Writing result to RNNLM-SCORE"
paste model-pos-score model-neg-score | awk '{print $1 " " $2 " " $1/$2;}' > RNNLM-SCORE

echo "Clean up"
rm train.neg train.pos valid.neg valid.pos model-pos-score model-neg-score test.txt test-pos.txt test-neg.txt
rm train-neg.txt train-pos.txt test-id.txt model-neg model-pos
rm model-neg.output.txt model-pos.output.txt
}

function Word2VecExec
{
CheckFile $1
CheckFile $2
CheckFile $3
local vecRes="sentence_vectors.txt"
local lenFile1=`wc -l < $1`
local lenFile2=`wc -l < $2`
local lenFile3=`wc -l < $3`

echo "Merging pos, neg and neutral file"
cat $1 $2 $3 | awk 'BEGIN{a=0;}{print "_*" a " " $0; a++;}' > vec-id.txt

echo "Start computating Vectors"
time $WORD2VECBINARY -train vec-id.txt -output vectors.txt -cbow 0 -size 100 -window 10 -negative 5 -hs 0 -sample 1e-4 -threads 40 -binary 0 -iter 20 -min-count 1 -sentence-vectors 1

echo "Keeping only sentence vectors"
grep '^_\*' vectors.txt > $vecRes

echo "Splitting vectors in pos, neg files"
head -n $lenFile1 $vecRes > pos_vectors.txt
head -n $(($lenFile1 + $lenFile2)) $vecRes | tail -n $lenFile2 > neg_vectors.txt

echo "Clean up"
rm vectors.txt $vecRes vec-id.txt
}

function LiblinearExec
{
CheckFile pos_vectors.txt
CheckFile neg_vectors.txt

head -n $TRAININGSIZE pos_vectors.txt > pos_vectors.tmp
head -n $TRAININGSIZE neg_vectors.txt > neg_vectors.tmp

cat pos_vectors.tmp neg_vectors.tmp | awk 'BEGIN{a=0;}{if (a<12500) printf "1 "; else printf "-1 "; for (b=1; b<NF; b++) printf b ":" $(b+1) " "; print ""; a++;}' > train.txt

tail -n $TESTSIZE pos_vectors.txt > pos_vectors.tmp
tail -n $TESTSIZE neg_vectors.txt > neg_vectors.tmp
cat pos_vectors.tmp neg_vectors.tmp | awk 'BEGIN{a=0;}{if (a<25000) printf "1 "; else printf "-1 "; for (b=1; b<NF; b++) printf b ":" $(b+1) " "; print ""; a++;}' > test.txt
$LIBLINEARTRAINBINARY -s 0 train.txt model.logreg
$LIBLINEARPREDICTBINARY -b 1 test.txt model.logreg out.logreg
tail -n $(($TESTSIZE * 2)) out.logreg > SENTENCE-VECTOR.LOGREG

echo "Clean up"
rm *.tmp train.txt test.txt model.logreg out.logreg
}

function PrintFinalResults
{
cat RNNLM-SCORE | awk -v size=$TESTSIZE' \
BEGIN{cn=0; corr=0;} \
{ \
  if ($3<1) if (cn<size) corr++; \
  if ($3>1) if (cn>=size) corr++; \
  cn++; \
} \
END{print "RNNLM accuracy: " corr/cn*100 "%";}'

cat SENTENCE-VECTOR.LOGREG | awk -v size=$TESTSIZE' \
BEGIN{cn=0; corr=0;} \
{ \
  if ($2>0.5) if (cn<size) corr++; \
  if ($2<0.5) if (cn>=size) corr++; \
  cn++; \
} \
END{print "Sentence vector + logistic regression accuracy: " corr/cn*100 "%";}'

paste RNNLM-SCORE SENTENCE-VECTOR.LOGREG | awk -v size=$TESTSIZE' \
BEGIN{cn=0; corr=0;} \
{ \
  if (($3-1)*7+(0.5-$5)<0) if (cn<size) corr++; \
  if (($3-1)*7+(0.5-$5)>0) if (cn>=size) corr++; \
  cn++; \
} \
END{print "FINAL accuracy: " corr/cn*100 "%";}'
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
    -kv|--keepVectors)
    KEEPVECTORTMP="$2"
    shift
    ;;
    *)
            # unknown option
    ;;
esac
shift
done

if [ ! -z $TRAININGSIZETMP ]; then
    TRAININGSIZE=$TRAININGSIZETMP
fi
if [ ! -z $TESTSIZETMP ]; then
    TESTSIZE=$TESTSIZETMP
fi

if [ -z $STEPS ]; then
    echo "Shitty script fuck you. Usage:"
    echo "-s --steps: set the step starting point"
    echo "  -s 0    Build rnnlm, word2vec and liblinear"
    echo "  -s 1    Tokenization and file cleanup"
    echo "  -s 2    Split the corpus in pos, neg and neutral files"
    echo "  -s 3    Calculate paragraph vector. It will take a lot of time and a lot of memory"
    echo "  -s 9    do steps 1,2"
    echo "  -s 10   Rnnlm train and test"
    echo "  -s 11   Sentence vectors/liblinear train and test"
    echo "  -s 19   Process result files and output accurancy"
    echo ""
    echo "-m --multiAlanFreETIMPERA: using bombastic multi model alg. by Fre"
    echo "  -m 1 Tokenization and file cleanup (same as s -1)"
    echo "  -m 2 Split the corpus in different files, one for every emotes"
    echo "  -m 3 Rnnlm train for every emotes"
    echo "  -m 4 Rnnlm test using the bombastic algoritm"
    echo "  -m 9 Do step 1,2,3,4"
    echo ""
    echo "-i --input: input text file. In step -s 1 IT WILL BE OVERWRITTEN"
    echo ""
    echo "-t --training: training line size. Default: 12500"
    echo ""
    echo "-tt --test: number of test lines. Default: 25000"
    echo ""
    echo "-kv --keepVectors: don't clean up useless vectors during -s 3 (NOT YET IMPLEMENTED)"
else
    case $STEPS in
		0)
		Build
		;;
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
        ;;
        10) 
        RnnlmExec $ALLPOSFILE $ALLNEGFILE
        ;;
        11)
        LiblinearExec
        ;;
        19)
        PrintFinalResults
        ;;
        *)
        #doall
        ;;
    esac 
fi
