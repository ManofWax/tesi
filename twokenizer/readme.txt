Usage:
python twokenize.py /path/to/inputfile.txt

The output is a file (in the same directory of twokenize.py) called inputfile.txt.out

Warning:
It's fucking slow... 
My advice is to split the input file in n+2 files where n is the number of cores on your machine.
I did the following in my quadcore pc:
wax@pasifae:$ wc -l input.txt 
27010000 input.txt

Since 27010000/6 = 4501666 I split the file:
wax@pasifaes:$split -l 4600000 input.txt inputpart.txt

In this way I end up with 6 files (inputpart.txtaa, inputpart.txtab etc.) and I simply launched six times
the twokenize.py in 6 different terminals.

yeah I know I should write a shell script to automate that :P

