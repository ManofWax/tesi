#costants
positiveEmotes="kappa|4head|elegiggle|kappapride|kreygasm|heyguys|anele"
negativeEmotes="residentsleeper|pjsalt|wutface|notlikethis|failfish|biblethump|dansgame|babyrage"
IFS='|' read -r -a arrayPos <<< "$positiveEmotes"
IFS='|' read -r -a arrayNeg <<< "$negativeEmotes"

EMOTESDIR="Emotes"
POSEMOTESDIR="$EMOTESDIR/pos"
NEGEMOTESDIR="$EMOTESDIR/neg"
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
LIBLINEARPREDICTBINARY="liblinear/predict"
MULTIRNNLMSCOREDIR="MultiRnnlmScore"

#helper functions
function CheckFile {
if [ ! -f $1 ]; then
    echo "File not found!"
    exit
fi
}
#end helper functions

#
#multiBombastic algoritm
#

function Multi_ProcessEmoticons
{
echo "Creating Emoticons Dir"
mkdir $EMOTESDIR
echo "Creating Pos and Neg emoticons Dir"
mkdir $POSEMOTESDIR
mkdir $NEGEMOTESDIR

#wtf is this magic?!
IFS='|' read -r -a array <<< "$positiveEmotes"
for i in "${array[@]}"
do
    echo "Processing $i"
    grep -E -i $i $1 > $POSEMOTESDIR/$i.txt
    sed -i -e "s/$i//gI" $POSEMOTESDIR/$i.txt
    sed -i -e "s/  \+/ /g" $POSEMOTESDIR/$i.txt
    sed -i -e '/^\s*$/d' $POSEMOTESDIR/$i.txt   
done

IFS='|' read -r -a array <<< "$negativeEmotes"
for i in "${array[@]}"
do
    echo "Processing $i"
    grep -E -i $i $1 > $NEGEMOTESDIR/$i.txt
    sed -i -e "s/$i//gI" $NEGEMOTESDIR/$i.txt
    sed -i -e "s/  \+/ /g" $NEGEMOTESDIR/$i.txt
    sed -i -e '/^\s*$/d' $NEGEMOTESDIR/$i.txt   
done
}

function Multi_RnnlmTrain
{
for i in `ls $POSEMOTESDIR/*.txt`
do
    _multi_rnnlmTrain $i
    #aggiungi cleanup
done

for i in `ls $NEGEMOTESDIR/*.txt`
do
    _multi_rnnlmTrain $i
done
}

function _multi_rnnlmTrain
{
dir=$1
head -n $TRAININGSIZE $dir > $dir.train.tmp
tail -n 200 $dir > $dir.valid.tmp
$RNNLMBINARY -rnnlm $dir.model -train $dir.train.tmp -valid $dir.valid.tmp -hidden 50 -direct-order 3 -direct 200 -class 100 -bptt 4 -bptt-block 10 -binary

echo "Clean up"
rm $POSEMOTESDIR/*.tmp $NEGEMOTESDIR/*.tmp $i.model.output.txt
}

function Multi_RnnlmTest
{
mkdir $MULTIRNNLMSCOREDIR
echo "Deleting old scores"
rm $MULTIRNNLMSCOREDIR/*.score

IFS='|' read -r -a arrayPos <<< "$positiveEmotes"
for i in "${arrayPos[@]}"
do
    echo "Processing $i"
    head -n $(($TRAININGSIZE + 500)) $POSEMOTESDIR/$i.txt | tail -n 500 > $POSEMOTESDIR/$i.test
done

IFS='|' read -r -a arrayNeg <<< "$negativeEmotes"
for i in "${arrayNeg[@]}"
do
    head -n $(($TRAININGSIZE + 500)) $NEGEMOTESDIR/$i.txt | tail -n 500 > $NEGEMOTESDIR/$i.test 
done

cat $POSEMOTESDIR/*.test $NEGEMOTESDIR/*.test > multiTest.txt
awk 'BEGIN{a=0;}{print a " " $0; a++;}' < multiTest.txt > multi-id.txt

for i in "${arrayPos[@]}"
do
    echo "Testing $i"
    $RNNLMBINARY -rnnlm $POSEMOTESDIR/$i.txt.model -test multi-id.txt -nbest > $i.score
done
for i in "${arrayNeg[@]}"
do
    echo "Testing $i"
    $RNNLMBINARY -rnnlm $NEGEMOTESDIR/$i.txt.model -test multi-id.txt -nbest > $i.score
done

mv *.score $MULTIRNNLMSCOREDIR

echo "Clean up"
rm multiTest.txt multi-id.txt
}

function Multi_PrintFinalResults
{
for i in $MULTIRNNLMSCOREDIR/*.score
do
    if [ `head -n 1 $i | wc -w` -gt 2 ]; then
        #deleting useless header and footer
        tail -n +4 $i > $i.tmp
        head -n -4 $i.tmp > $i
        rm $i.tmp
    fi
done

#local emotesToPastePos="`echo $positiveEmotes | sed -e 's/|/.score /gI'`.score "
#local emotesToPasteNeg="`echo $negativeEmotes | sed -e 's/|/.score /gI'`.score"

#paste $emotesToPastePos > MULTI_RNNLM_POS
#paste $emotesToPasteNeg > MULTI_RNNLM_NEG

#Every pos emotes vs every neg
for i in "${arrayPos[@]}"
do
    for y in "${arrayNeg[@]}"
    do
        paste $MULTIRNNLMSCOREDIR/$i.score $MULTIRNNLMSCOREDIR/$y.score \
        | awk '{print $1/$2;}' > $MULTIRNNLMSCOREDIR/$i.$y.SCORE
    done
done

paste $MULTIRNNLMSCOREDIR/*.SCORE > RNNLM-SCORE

cat RNNLM-SCORE | awk '\
BEGIN{cn=0; corr=0;} \
{ \
  tmp_pos=0;
  tmp_neg=0;
  for(i=0;i<NF;i++) ($i<1) ? tmp_pos++ : tmp_neg++; \    
  if (tmp_pos>=tmp_neg) if (cn<3500) corr++; \
  if (tmp_pos<tmp_neg) if (cn>=3500) corr++; \
  cn++; \
} \
END{print "RNNLM accuracy: " corr/cn*100 "%";}'

#Select the highest score from pos and the highest score from neg
#IT DOESNT WORK FUCK MY LIFE
#awk '{m=$1;for(i=1;i<=NF;i++)if($i<m)m=$i;print m}' < MULTI_RNNLM_POS > RES_POS
#awk '{m=$1;for(i=1;i<=NF;i++)if($i<m)m=$i;print m}' < MULTI_RNNLM_NEG > RES_NEG
#echo "Writing result to RNNLM-SCORE"
#paste RES_POS RES_NEG | awk '{print $1 " " $2 " " $1/$2;}' > RNNLM-SCORE

echo "Clean up"
rm $MULTIRNNLMSCOREDIR/*.SCORE
#rm MULTI_RNNLM_POS MULTI_RNNLM_NEG RES_POS RES_NEG
}
#end multiBombastic algoritm

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
wget https://raw.githubusercontent.com/ManofWax/tesi/master/twokenizer/twokenize.py -O twokenize.py
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
    -m|--multiBombastic)
    STEPSMULTI="$2"
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

if [ ! -z $STEPS ] && [ ! -z $STEPSMULTI ]; then
    echo "you CANNOT use both -s and -m!"
    exit
fi
if [ ! -z $TRAININGSIZETMP ]; then
    TRAININGSIZE=$TRAININGSIZETMP
fi
if [ ! -z $TESTSIZETMP ]; then
    TESTSIZE=$TESTSIZETMP
fi

if [ -z $STEPS ] && [ -z $STEPSMULTI ]; then
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
    echo "-m --multiBombastic: using bombastic multi model alg. by Fre"
    echo "  -m 0 Build rnnlm, word2vec and liblinear (same as -s 0)"
    echo "  -m 1 Tokenization and file cleanup (same as -s 1)"
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
fi
if [ ! -z $STEPS ]; then
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
if [ ! -z $STEPSMULTI ]; then
    case $STEPSMULTI in
        0)
        Build
        ;;
        1)
        Tokenizer $INPUT
        ;;
        2)
        Multi_ProcessEmoticons $INPUT
        ;;
        3)
        Multi_RnnlmTrain
        ;;
        4)
        Multi_RnnlmTest
	    ;;
	    5)
	    Multi_PrintFinalResults
        ;;
        *)
        ;;
    esac
fi