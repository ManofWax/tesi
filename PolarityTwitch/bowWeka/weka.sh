#!/bin/bash

#input
TRAINPOS="./dataset/pos.train"
TRAINNEG="./dataset/neg.train"
TESTPOS="./dataset/pos.test"
TESTNEG="./dataset/neg.test"

#tmp files
TRAINARFF="train.arff"
TESTARFF="test.arff"

#output
RESULTS="results-bow.txt"
PREDICTIONS="predictions-bow.txt"

tr -d "'\r" < $TRAINPOS > train-pos-tmp.wk
awk '{print "'\''"$0"'\'',pos"}' train-pos-tmp.wk > train-pos.wk

tr -d "'\r" < $TRAINNEG > train-neg-tmp.wk
awk '{print "'\''"$0"'\'',neg"}' train-neg-tmp.wk > train-neg.wk

tr -d "'\r" < $TESTPOS > test-pos-tmp.wk
awk '{print "'\''"$0"'\'',pos"}' test-pos-tmp.wk > test-pos.wk

tr -d "'\r" < $TESTNEG > test-neg-tmp.wk
awk '{print "'\''"$0"'\'',neg"}' test-neg-tmp.wk > test-neg.wk

#create training set arff
echo "@relation twitch-train" > $TRAINARFF
echo "@attribute line string" >> $TRAINARFF
echo "@attribute class_POLARITY {pos,neg}" >> $TRAINARFF
echo "@data" >> $TRAINARFF
cat train-pos.wk >> $TRAINARFF
cat train-neg.wk >> $TRAINARFF

#create test set arff
echo "@relation twitch-test" > $TESTARFF
echo "@attribute line string" >> $TESTARFF
echo "@attribute class_POLARITY {pos,neg}" >> $TESTARFF
echo "@data" >> $TESTARFF
cat test-pos.wk >> $TESTARFF
cat test-neg.wk >> $TESTARFF

# setting weka variables
METACLASSIFIER="weka.classifiers.meta.FilteredClassifier"
CLASSIFIER="weka.classifiers.functions.LibLINEAR -- -S 0 -C 1.0 -E 0.001 -B 1.0" #L2-regularized logistic regression (primal)

echo "Starting Classification..."
echo "Train: $TRAINARFF "
echo "Test: $TESTARFF "
echo "Classifier: $CLASSIFIER"

#run classification
java -Xmx2G -cp "./weka/*" $METACLASSIFIER -t $TRAINARFF -T $TESTARFF -d tmp.model.wk -o -i -F "weka.filters.MultiFilter -F \"weka.filters.unsupervised.attribute.StringToWordVector -R 1 -W 1000 -prune-rate -1.0 -T -I -N 0 -stemmer weka.core.stemmers.NullStemmer -M 1 -tokenizer \\\"weka.core.tokenizers.WordTokenizer -delimiters \\\\\\\" \\\\\\\"\\\"\" -F \"weka.filters.unsupervised.attribute.Reorder -R 2-last,1\"" -W $CLASSIFIER > $RESULTS

#save predictions
java -cp "./weka/*" $METACLASSIFIER -T $TESTARFF -l tmp.model.wk -p 0 > $PREDICTIONS

#clean
rm *.wk
rm *.arff

echo "Predictions in $PREDICTIONS"
echo "Results in $RESULTS"
