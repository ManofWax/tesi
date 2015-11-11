for y in *.pos
do
    for i in *.pos
    do
        /bin/bash rnnlmExec.sh  $y $i
    done
done

#merge the results
for i in `ls -d */`; do awk -v name="$i" '{ print(name, $3)}' < $i/RESULT.TXT >> RESULT.txt; done

