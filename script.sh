#Cleanup
rm raw_out compare changes updates dl_links 2> /dev/null

#Check if db exist
if [ -e anime_db ]
then
    mv anime_db anime_db_old
else
    echo "DB not found!"
fi

#Fetch
echo Fetching updates:
cat animes | while read url; do
	name=$(echo $url | cut -d / -f5)
	latest=$(curl -s $url | grep 'subtitles' | grep 'arabic' | grep -Eo '[0-9]{7}' | sort -r | head -1)
	sub=$(curl -s $url"/arabic/"$latest | grep -A 3 'Release info' | tail -1 | sed 's/ //g' | tr -d "\n\r")
	author=$(curl -s $url"/arabic/"$latest | grep -A 1 /u/ | head -2 | tail -1 | sed 's/ //g' | tr -d "\n\r")
	link=$(curl -s $url"/arabic/"$latest | grep '/subtitles/arabic-text/' | cut -d '"' -f2)
	echo $name"="$sub "https://subscene.com"$link $author >> raw_out
done
cat raw_out | sort | cut -d ' ' -f1 > anime_db

#Compare
echo Comparing:
cat anime_db | while read show; do
	name=$(echo $show | cut -d = -f1 | head -1)
	new=`cat anime_db | grep $name`
	old=`cat anime_db_old | grep $name`
	diff <(echo "$old") <(echo "$new") | grep ^"<\|>" >> compare
done
awk '!seen[$0]++' compare > changes

#Info
if [ -s changes ]
then
	echo "Here's the new episodes!"
	cat changes | grep ">" | cut -d ">" -f2 | tee updates
else
    echo "No changes found!"
fi

#Downloads
if [ -s updates ]
then
    echo "Download Links!"
	for show in `cat updates | cut -d = -f1`; do cat raw_out | grep $show ; done 2>&1 | tee dl_links
else
    echo "No new episodes!"
fi

#Telegram
cat dl_links | while read line; do
	sub=$(echo $line | cut -d = -f2 | cut -d ' ' -f1)
	link=$(echo $line | cut -d = -f2 | cut -d ' ' -f2)
	author=$(echo $line | cut -d = -f2 | cut -d ' ' -f3)
	./telegram -t $BOTTOKEN -c @NineAnimeTracker -M "New episode available!
	Subtitle: *$sub*
	*By*: $author
	*Download Link*: [Here]($link)"
done

#Push
git config --global user.email "$GITMAIL"; git config --global user.name "$GITUSER"
git add anime_db; git commit -m "Sync: $(date +%d.%m.%Y-%R)"
git push -q https://$GITUSER:$GITPASS@gitlab.com/yshalsager/myanimetracker.git HEAD:subscene
