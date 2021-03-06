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
	info=`curl -s $url | grep 'itemprop="item" href="https://anidl' | tr '>' '\n' | grep 'alt=' | cut -d '"' -f6 | sed 's/&#8211;/-/g'`
	HD=`curl -s $url | tr '>' '\n' | grep '720p' | grep -Eo "(http|https)://[a-zA-Z0-9./?=_-]*" | head -1`
	SD=`curl -s $url | tr '>' '\n' | grep '480p' | grep -Eo "(http|https)://[a-zA-Z0-9./?=_-]*" | head -1`
	echo $info"="$HD $SD >> raw_out
done
cat raw_out | sort | cut -d = -f1 > anime_db

#Compare
echo Comparing:
cat anime_db | while read show; do
	name=$(echo $show | cut -d ' ' -f1 | head -1)
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
	for show in `cat updates | cut -d ' ' -f2`; do cat raw_out | grep $show ; done 2>&1 | tee dl_links
else
    echo "No new episodes!"
fi

#Telegram
cat dl_links | while read line; do
	anime=$(echo $line | cut -d = -f1 | cut -d _ -f1)
	HD_link=$(echo $line | cut -d = -f2 | cut -d ' ' -f1)
	HD_size=$(wget --spider $HD_link  --server-response -O - 2>&1 | sed -ne '/Length:/{s/*. //;p}' | tail -1 | cut -d ' ' -f3)
	SD_link=$(echo $line | cut -d = -f2 | cut -d ' ' -f2)
	SD_size=$(wget --spider $SD_link  --server-response -O - 2>&1 | sed -ne '/Length:/{s/*. //;p}' | tail -1 | cut -d ' ' -f3)
	./telegram -t $BOTTOKEN -c @NineAnimeTracker -M "New episode available!
	*Anime*: $anime
	*720P*:
	*Download Link*: [Here]($HD_link)
	*Size*: $HD_size
	*480P*:
	*Download Link*: [Here]($SD_link)
	*Size*: $SD_size "
done

#Push
git config --global user.email "$GITMAIL"; git config --global user.name "$GITUSER"
git add anime_db; git commit -m "Sync: $(date +%d.%m.%Y-%R)"
git push -q https://$GITUSER:$GITPASS@gitlab.com/yshalsager/myanimetracker.git HEAD:anidl
