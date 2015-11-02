corpus=$1

# positive
grep -i "kappa" $corpus > kappa.pos
grep -i "4head" $corpus > 4head.pos
grep -i "kreygasm" $corpus > kreygasm.pos
grep -i "elegiggle" $corpus > elegiggle.pos

# negative
grep -i "wutface" $corpus > wutface.neg
grep -i "notlikethis" $corpus > notlikethis.neg
grep -i "failfish" $corpus > failfish.neg
grep -i "biblethump" $corpus > biblethump.neg
grep -i "dansgame" $corpus > dansgame.neg
grep -i "babyrage" $corpus > babyrage.neg

#remove emoticons
sed -e "s/kappa//g" < kappa.pos > kappa.pos.tmp
sed -e "s/4head//g" < 4head.pos > 4head.pos.tmp
sed -e "s/kreygasm//g" < kreygasm.pos > kreygasm.pos.tmp
sed -e "s/elegiggle//g" < elegiggle.pos > elegiggle.pos.tmp
sed -e "s/wutface//g" < wutface.neg > wutface.neg.tmp
sed -e "s/notlikethis//g" < notlikethis.neg > notlikethis.neg.tmp
sed -e "s/failfish//g" < failfish.neg > failfish.neg.tmp
sed -e "s/biblethump//g" < biblethump.neg > biblethump.neg.tmp
sed -e "s/dansgame//g" < dansgame.neg > dansgame.neg.tmp
sed -e "s/babyrage//g" < babyrage.neg > babyrage.neg.tmp

#removing multiple spaces and rewrite on filename.pos
for i in *.tmp
do
    sed 's/ \+/ /g;s/^ //g' < $i > $i.out
    sed '/^\s*$/d' $i.out > "${i%.*}"
done
rm *.tmp
rm *.out
