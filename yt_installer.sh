defcmd="fzf"
guicmd="rofi -dmenu -i" #uncomment next line for dmenu
#guicmd="dmenu -i -l 15"
promptcmd="$defcmd"
if [ -z "$*" ]; then 
    echo -n "Search: "
    read -r query
else
    case "$1" in
        -r) query=$(echo | $guicmd -p "Search: ")
            promptcmd="$guicmd -p Video:";;
        *) query="$*";;
    esac
fi
if [ -z "$query" ]; then exit; fi 
# sanitise the query
query=$(sed \
    -e 's|+|%2B|g'\
    -e 's|#|%23|g'\
    -e 's|&|%26|g'\
    -e 's| |+|g'\
    <<< "$query")
# fetch the results with the $query and
# delete all escaped characters
response="$(curl -s "https://www.youtube.com/results?search_query=$query" |\
    sed 's|\\.||g')"
# if unable to fetch the youtube results page, inform and exit
if ! grep -q "script" <<< "$response"; then echo "unable to fetch yt"; exit 1; fi
# regex expression to match video and playlist entries from yt result page
vgrep='"videoRenderer":{"videoId":"\K.{11}".+?"text":".+?[^\\](?=")'
pgrep='"playlistRenderer":{"playlistId":"\K.{34}?","title":{"simpleText":".+?[^\"](?=")'
# grep the id and title
# return them in format id (type) title
getresults() {
    grep -oP "$1" <<< "$response" |\
    awk -F\" -v p="$2" '{ print $1 "\t" p " " $NF}'
}
# get the list of videos/playlists and their ids in videoids and playlistids
videoids=$(getresults "$vgrep")
playlistids=$(getresults "$pgrep" "(playlist)")
# if there are playlists or videos, append them to list
[ -n "$playlistids" ] && ids="$playlistids\n"
[ -n "$videoids" ] && ids="$ids$videoids"
# url prefix for videos and playlists
videolink="https://youtu.be/"
playlink="https://youtube.com/playlist?list="
# prompt the results to user infinitely until they exit (escape)
clear
echo "Choose Song to Install: "
choice=$(echo -e "$ids" | cut -d'	' -f2 | $promptcmd) # dont show id
if [ -z "$choice" ]; then exit; fi	# if esc-ed then exit
id=$(echo -e "$ids" | grep -Fwm1 "$choice" | cut -d'	' -f1) # get id of choice
echo -e "$choice\t($id)"
echo "$query"
youtube-dl -o "$query".mp3 -x --audio-format mp3 "$videolink$id" 
