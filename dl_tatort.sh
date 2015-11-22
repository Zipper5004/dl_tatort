#! /bin/ksh
#benoetigt: ksh awk
#optional: notify-send sendmail
#script_version: 1.02

#variabeln
mediathek="http://mediathek.daserste.de/suche?searchText=tatort&topRessort=-&sort=date"
thetvdb="http://thetvdb.com/?tab=seasonall&id=83214&lid=14"
datetime=$(date "+%Y-%m-%d_%H")
fulldate=$(date "+%Y-%m-%d %H:%M:%S")
date=$(date "+%Y-%m-%d")
filename="mediathek_${date}.htm"
filenameTVDB="thetvdb_${date}.htm"
filenameMediaJSON=""
videoname=""
mediathekDL=""
dlfolder="$HOME/video/TV Shows/Tatort"

echo "$(date "+%Y-%m-%d %H:%M:%S"): $0"
#echo "$fulldate $(date "+%Y-%m-%d %H:%M:%S")"

#Argumente abgreifen
#d = directory to save files
#i = id for movie
#m = mail when download is done
#q = quiet download # hide wget's output
#r = remote directory to save files if connected (e.g. usb drive)
#v = url to direct download #not done yet
while getopts "d:i:r:v:q:" opt; do
  #
  case $opt in
     d) 
      echo "$(date "+%Y-%m-%d %H:%M:%S"): Directory: $OPTARG"
      dlfolder="$OPTARG"
      ;;
     i)
      documentId="$OPTARG"
      filename=${filename}_${documentId}
      echo "$fulldate documentId: $documentId"
      ;;
	 m)
      mail="$OPTARG"
	  ;;
	 q)
      q="--quiet"
      ;;
     r)
      if [ -d "$OPTARG" ]; then
       dlfolder="$OPTARG"
      fi;
      ;;
     v) echo $OPTARG
      exit 1
      ;;
     \?)
      echo "$fulldate Unbekannte Option: -$OPTARG ($OPTIND)"
      ;;
  esac
done

# Parameter umshiften erforderlich, da -wc etc sonst $1 waeren.
shift $((OPTIND - 1))

if [ ! -d "${dlfolder}" ]; then
    mkdir -p "${dlfolder}"; 
fi;
cd "${dlfolder}"

if [ -f $filename ]; then
    echo "$(date "+%Y-%m-%d %H:%M:%S"): ${filename} already exists"
fi

#Mediathek aufrufen
wget -q "${mediathek}" -O "${filename}" >/dev/null

#Fehler beim Aufruf
if [[ $? > 0 ]]; then
   echo "$(date "+%Y-%m-%d %H:%M:%S"): -2: $? Fehler beim Aufruf der Mediathek: ${mediathek}" >&2
   exit 2
fi
echo "$fulldate: ${filename}"

if [[ ${#documentId} == 0 ]]; then

 #index(in, find)
 #substr(string, start, length)

 #Document ID wird fuer den Download benoetigt
 documentId=$( awk '{
    v=index($0,"Video-tgl-ab-20-U");
    i=index($0,"documentId");
    if (v>0 && i>0) {
        s=substr($0,i+11,10);
        d=substr(s,0,index(s,"&")-1);
        print d;
        exit;
    }
 }' $filename);

 if [[ ${#documentId} == 0 ]]; then
    echo "$(date "+%Y-%m-%d %H:%M:%S"): -3: Keine Videos gefunden" >&2
    exit 3
 fi

 #Staffelname / Folge
 #saesonname=$( awk '{
 #   v=index($0,"Video-tgl-ab-20-Uhr");
 #   i=index($0,"Tatort/");
#	j=index($0,"Polizeiruf-110/");
#    h=index($0,"Hörfassung");
 #   if (v>0 && i>0 && h == 0) {
 #       s=substr($0,i+7);
 #       d=substr(s,0,index(s,"-Video-tgl-ab-20-Uhr")-1);
 #       print d;
 #       exit;
 #   } else if (v>0 && j>0 && h == 0) {
#		s=substr($0,j+15);
#        d=substr(s,0,index(s,"-Video-tgl-ab-20-Uhr")-1);
#        print d;
#        exit;
#	}
# }' $filename);
#else
 #Staffelname / Folge
 saesonname=$( awk '{
    v=index($0,$documentId);
    i=index($0,"Tatort/");
    si=substr($0,i+7,50);
    j=index(si,"Tatort-");
    if (v>0 && i>0) {
        if( j > 0 ) {
          d=substr(si,j+7,29);
        } else {
          d=substr(js,0,29);
        }
        print d;
        exit;
    }
 }' $filename);

fi #documentId was filled
saesonname=$(echo $saesonname | awk '{gsub("-Video-tgl-ab-20-",""); print $0}')

if [[ ${#saesonname} == 0 ]]; then
    echo "$(date "+%Y-%m-%d %H:%M:%S"): -4: Kein saesonname fuer documentId=$documentId in $filename gefunden." >&2
    exit 4
fi

if [ -f "${saesonname}.done" ]; then
    echo "$(date "+%Y-%m-%d %H:%M:%S"): -5: ${saesonname}: Video bereits geladen." >&2
    exit 5
fi

echo "$(date "+%Y-%m-%d %H:%M:%S"): '${saesonname}' gefunden. Starte Aufbereitung"
start="${saesonname}"
touch "${start}.start"

#SQL insert
sqlite3 tatorte.db <<EOSQL
	insert into tartort_history values('${saesonname}',0,date('now'));
EOSQL

saesonname=$(echo $saesonname | awk '{gsub("-"," "); print $0}')

if [[ ! -f "${filenameTVDB}" ]]; then
    #TheTVDB aufrufen
    wget -q "${thetvdb}" -O "${filenameTVDB}" >/dev/null

    #Fehler beim Aufruf
    if [[ $? > 0 ]]; then
		
		#versuche alten TVDB-Link zu verwenden
		if [[ -f "thetvdb.com.htm" ]]; then
			filenameTVDB="thetvdb.com.htm"
			echo "TheTVDB nicht erreichbar. Verwende alten Link"
		else
			videoname=${saesonname}
			echo "$? Fehler beim Aufruf der TVDB: ${TheTVDB}. Verwende ${videoname}"
		fi
    fi
fi


echo "$(date "+%Y-%m-%d %H:%M:%S"): ${filenameTVDB}"

#Kompletten Seasonname suchen
#print "Tatort_S" season "_" name ".mp4";
#print "href:" href " season:" season " name:" name;
videoname=$( awk -vvname="$saesonname" '{
    v=index($0,vname);
    if (v>0) {
        href=substr($0,index($0,"<a href=")+9)
        href=substr(href,0,index(href,">")-2)
        s=substr($0,index($0,href) + length(href)+2);
        season=substr(s,0,index(s,"</a>")-1)
        href=substr(s,index(s,"<a href=")+9)
        href=substr(href,0,index(href,">")-2)
        s=substr(s,index(s,href) + length(href)+2);
        name=substr(s,href,index(s,"</a>")-1)
        print "Tatort_S" season "_" name ".mp4";
        exit;
    }
}' $filenameTVDB );
echo "$(date "+%Y-%m-%d %H:%M:%S"): ${videoname}"

if [[ ${#videoname} == 0 ]]; then
    videoname="${saesonname}.mp4"
    echo "$fulldate $?: Videoname nicht in der TVDB gefunden. Verwende ${videoname}"
else

	videoname=$(echo $videoname | awk '{gsub(" - ","_"); print $0}')
	#umlaute
	videoname=$(echo $videoname | awk '{gsub("%C3%A4","ae"); print $0}')
	videoname=$(echo $videoname | awk '{gsub("%C3%B6","oe"); print $0}')
	videoname=$(echo $videoname | awk '{gsub("%C3%BC","ue"); print $0}')
	videoname=$(echo $videoname | awk '{gsub("%C3%84","Ae"); print $0}')
	videoname=$(echo $videoname | awk '{gsub("%C3%96","Oe"); print $0}')
	videoname=$(echo $videoname | awk '{gsub("%C3%9C","Ue"); print $0}')
	videoname=$(echo $videoname | awk '{gsub("%C3%9F","ss"); print $0}')
	
	videoname=$(echo $videoname | awk '{
	    v=index($0," x ");
	    b=index($0,"_S")
	    season=substr($0,b+2,v-b-2)
	    begin=substr($0,0,v)
	    s=substr($0,length(begin)+3)
	    b=index(s,"_")
	    episode=substr(s,0,b-1)
	    s=substr(s,length(episode)+1)
	    if(length(episode) < 2) { episode=0 episode; }
	    print "Tatort_S" season "E" episode s
	}')
	videoname=$(echo $videoname | awk '{gsub(" ","_"); print $0}')

	if [[ ${#videoname} == 0 ]]; then
	    echo "-5: Kein Videoname gefunden."
	    exit 5
	fi
fi

echo "$(date "+%Y-%m-%d %H:%M:%S"): ${videoname}"


mediathekDL="http://www.ardmediathek.de/play/media/${documentId}?devicetype=pc&features=flash"
filenameMediaJSON="mediaJSON_${documentId}.htm"
#Mediathe aufrufen
wget -q "${mediathekDL}" -O "${filenameMediaJSON}" >/dev/null

#Fehler beim Aufruf
if [[ $? > 0 ]]; then
    echo "-10: $? Fehler beim Aufruf der Mediathek: ${mediathekDL}" >&2
    exit 10
fi
echo "$(date "+%Y-%m-%d %H:%M:%S"): ${filenameMediaJSON}"

mediathekDL=$( awk '{
    v=index($0,"_quality");
    if (v>0) {
        s=$0;
        while(length(s) > 0) {
            s=substr(s,index(s,"_quality")+8);
            d=index(s,":");
            k=index(s,",");
            q=substr(s,d+1,k-d-1);
            if(q == 3) {
            s=substr(s,index(s,"_stream")+10);
            d=index(s,"\"");
            json=substr(s,0,d-1);
            print json;
        }
    }
        d=substr(s,0,index(s,"_stream")+3);
        exit;
    }
}' $filenameMediaJSON);

if [[ ${#mediathekDL} == 0 ]]; then
 echo "$(date "+%Y-%m-%d %H:%M:%S"): -11: Kein mediathek-Download gefunden." >&2
 exit 11
fi

if [ -f "${videoname}" ]; then
    echo "$(date "+%Y-%m-%d %H:%M:%S"): -12: ${videoname}: Video bereits vorhanden." >&2
    exit 12
fi

#Video herunterladen
echo "$(date "+%Y-%m-%d %H:%M:%S"): Speichere ${videoname} nach '${dlfolder}'"

which notify-send
#notify-send is installed
if [[ $? = 0 ]]; then
    notify-send "Speichere ${videoname}"
fi

wget ${q} "${mediathekDL}" -O "${videoname}.filepart" >/dev/null

#Fehler beim Aufruf
if [[ $? > 0 ]]; then
    echo "$(date "+%Y-%m-%d %H:%M:%S"): -13: $? Fehler beim Aufruf der Mediathek: ${mediathekDL}" >&2

    which notify-send
    #notify-send is installed
    if [[ $? = 0 ]]; then
        notify-send "Fehler beim Aufruf der Mediathek: ${mediathekDL}. Siehe Protokolleintrag"
    fi
    exit 13
fi
mv "${videoname}.filepart" "${videoname}"
mv "${start}.start" "${start}.done"

#SQL update
sqlite3 tatorte.db <<EOSQL
	update tartort_history set state = 1 where movie_name='${saesonname}';
EOSQL

echo "$(date "+%Y-%m-%d %H:%M:%S"): ${mediathekDL}"

echo "$(date "+%Y-%m-%d %H:%M:%S"): [DONE]"

which notify-send
#notify-send is installed
if [[ $? = 0 ]]; then
    notify-send "Tatort erfolgreich heruntergeladen"
fi

if [[ ${#mail} > 0 ]]; then
 echo "dl_datort.sh: ${videoname} heruntergeladen" > mail.txt
 mail -s "dl_datort.sh: ${videoname} heruntergeladen" -r "dl_tatort@nobody.com" ${mail} < mail.txt
fi
