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
