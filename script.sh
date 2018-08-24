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
	HD=`wget -qO- $anime | cat | grep '<p>720p ' | tail -1`
	GD_HD=$(echo $HD | cut -d '"' -f2)
	ZS_HD=$(echo $HD | cut -d '"' -f4)
	MR_HD=$(echo $HD | cut -d '"' -f6)
	Size_HD=$(echo $HD | grep -Po '[0-9]* MB')
	info=`curl -s $ZS_HD | grep ".mkv" | head -1 | cut -d _ -f 2,3`
	SD=`wget -qO- $anime | cat | grep '<p>480p ' | tail -1`
	GD_SD=$(echo $SD | cut -d '"' -f2)
	ZS_SD=$(echo $SD | cut -d '"' -f4)
	MR_SD=$(echo $SD | cut -d '"' -f6)
	Size_SD=$(echo $SD | grep -Po '[0-9]* MB')
	echo $info"="\"$GD_HD\" \"$ZS_HD\" \"$MR_HD\" \"$Size_HD\" \"$GD_SD\" \"$ZS_SD\" \"$MR_SD\" \"$Size_SD\">> raw_out
done
cat raw_out | sort | cut -d = -f1 | sed 's/-/_/g' > anime_db

#Compare
echo Comparing:
cat anime_db | while read show; do
	name=$(echo $show | cut -d _ -f1)
	new=`cat anime_db | grep $name`
	old=`cat anime_db_old | grep $name`
	diff <(echo "$old") <(echo "$new") | grep ^"<\|>" >> compare
done
awk '!seen[$0]++' compare > changes

#Info
if [ -s changes ]
then
	echo "Here's the new episodes!"
	cat changes | grep ">" | cut -d ">" -f2 | sed 's/ //g' 2>&1 | tee updates
else
    echo "No changes found!"
fi

#Downloads
if [ -s updates ]
then
    echo "Download Links!"
	for show in `cat updates | cut -d = -f2`; do cat raw_out | grep $show ; done 2>&1 | tee dl_links
else
    echo "No new episodes!"
fi

#Telegram
cat dl_links | while read line; do
	anime=$(echo $line | cut -d = -f1 | cut -d _ -f1)
	ep=$(echo $line | cut -d = -f1 | cut -d _ -f2)
	GD_HD=$(echo $line | cut -d '"' -f2)
	ZS_HD=$(echo $line | cut -d '"' -f4)
	MR_HD=$(echo $line | cut -d '"' -f6)
	size_HD=$(echo $line | cut -d '"' -f8)
	GD_SD=$(echo $line | cut -d '"' -f10)
	ZS_SD=$(echo $line | cut -d '"' -f12)
	MR_SD=$(echo $line | cut -d '"' -f14)
	size_SD=$(echo $line | cut -d '"' -f16)
	./telegram -t $BOTTOKEN -c @NineAnimeTracker -M "New episode available!
	*Anime*: $anime
	*Episode*: $ep
	*720P*:
	*Download Link*: [GD]($GD_HD) | [ZS]($ZS_HD) | [MR]($MR_HD)
	*Size*: $size_HD
	*480P*:
	*Download Link*: [GD]($GD_SD) | [ZS]($ZS_SD) | [MR]($MR_SD)
	*Size*: $size_SD"
done

#Push
git add anime_db; git -c "user.name=$gituser" -c "user.email=$gitmail" commit -m "Sync: $(date +%d.%m.%Y)"
git push -q https://$GITUSER:$GITPASS@gitlab.com/yshalsager/myanimetracker.git HEAD:daizurin
