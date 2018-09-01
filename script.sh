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
cat animes | while read anime; do
	info=`wget -qq $anime -O page`
	name=$(cat page | grep '"og:title" content="' | cut -d '"' -f4 | cut -d ' ' -f3-10 | sed 's/با.*//g' | sed 's/ *$//')
	ep=$(cat page | grep '<strong>قسمت' | tail -1 | grep -Po '[0-9]*')
	HD_1=$(cat page | grep 'mkv' | grep '720-x265' | grep 's1' | tail -1 | cut -d '"' -f4)
	HD_2=$(cat page | grep 'mkv' | grep '720-x265' | grep 's2' | tail -1 | cut -d '"' -f4)
	SD_1=$(cat page | grep 'mkv' | grep '480' | grep 's1' | tail -1 | cut -d '"' -f4)
	SD_2=$(cat page | grep 'mkv' | grep '480' | grep 's2' | tail -1 | cut -d '"' -f4)
	echo $name"="$ep"="\"$HD_1\" \"$HD_2\" \"$SD_1\" \"$SD_2\" >> raw_out
done
cat raw_out | sort | cut -d = -f1,2 > anime_db

#Compare
echo Comparing:
cat anime_db | while read show; do
	name=$(echo $show | cut -d = -f1 | head -1)
	new=`cat anime_db | grep "$name"`
	old=`cat anime_db_old | grep "$name"`
	diff <(echo "$old") <(echo "$new") | grep ^"<\|>" >> compare
done
awk '!seen[$0]++' compare > changes

#Info
if [ -s changes ]
then
	echo "Here's the new episodes!"
	cat changes | grep ">" | cut -d ">" -f2 | sed 's/ //1' | tee updates
else
    echo "No changes found!"
fi

#Downloads
if [ -s updates ]
then
    echo "Download Links!"
    cat updates | while read show; do cat raw_out | grep "$show" ; done 2>&1 | tee dl_links
else
    echo "No new episodes!"
fi

#Telegram
cat dl_links | while read line; do
	anime=$(echo $line | cut -d = -f1)
	ep=$(echo $line | cut -d = -f2)
	HD_1=$(echo $line | cut -d '"' -f2)
	size_HD_1=$(wget --spider $HD_1  --server-response -O - 2>&1 | sed -ne '/Length:/{s/*. //;p}' | tail -1 | cut -d '(' -f2 | cut -d ')' -f1)
	HD_2=$(echo $line | cut -d '"' -f4)
	SD_1=$(echo $line | cut -d '"' -f6)
	size_SD_1=$(wget --spider $SD_1  --server-response -O - 2>&1 | sed -ne '/Length:/{s/*. //;p}' | tail -1 | cut -d '(' -f2 | cut -d ')' -f1)
	SD_2=$(echo $line | cut -d '"' -f8)
	./telegram -t $BOTTOKEN -c @NineAnimeTracker -M "New episode available!
	*Anime*: $anime
	*Episode*: $ep
	*720P* (X265):
	*Download Link*: [S1]($HD_1) | [S2]($HD_2)
	*Size*: $size_HD_1
	*480P*:
	*Download Link*: [S1]($SD_1) | [S2]($SD_2)
	*Size*: $size_SD_1"
done

#Push
git add anime_db; git -c "user.name=$GITUSER" -c "user.email=$GITMAIL" commit -m "Sync: $(date +%d.%m.%Y)"
git push -q https://$GITUSER:$GITPASS@gitlab.com/yshalsager/myanimetracker.git HEAD:takanime
