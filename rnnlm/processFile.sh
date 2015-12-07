corpus=$1
emotes=$2
#read emots file
while IFS="read -r line || [[-n "$line"]]"; do
	grep -i "$line" $corpus > $line.txt
	sed -e "s/$line//g" < $line.txt > $line.out
done < "$emotes"

#removing multiple spaces and rewrite on filename.pos
for i in *.out
do
    sed 's/ \+/ /g;s/^ //g' < $i > $i.tmp
    sed '/^\s*$/d' $i.tmp > "${i%.*}"
done

#clear tmp files
rm *.tmp
rm *.out