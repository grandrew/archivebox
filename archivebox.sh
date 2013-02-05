#!/bin/bash
# ArchiveBox: Dropbox extended archive v.0.2b
# Ever thought of unnesessary files in your Dropbox? Have 24/7-running PCs?
#                 Or at least PCs with overlapping run time?
#                               Haz linuxz?
# With this script running, when you move/copy files to ~/Dropbox/ArchiveDrop folder,
# the files get moved to ~/ArchiveBox folder (outside of Dropbox). Also an index
# is created at ~/Dropbox/ArchiveIndex with empty files (or previews for jpg). 
# When you copy/move an index file to ~/Dropbox/ArchiveRequest, it is rewritten 
# by a script with real file. That's it! Works with all clients, including mobile,
# is able to synchronize ArchiveBox with many computers. Also processes 
# 'Camera Uploads' folder the same way as ArchiveDrop.
#
# Requirements:
# - modern linux distro with Dropbox (Mac may work too)
# - 'comm' utility
# - convert utility from ImageMagick
#
# Script installation:
# - (optional) change directories to whatever you like below
# - add this string to crontab (crontab -e) on all machines you want to sync:
#   * * * * * ~/archivebox.sh
# where ~/archivebox.sh is a full path to this script
#
# Archive usage:
# - all moved files appear in $DPBX_INDEX_DIR with 0kb file size (2 bytes to be correct)
# - you copy or move(it will be re-created anyway) a 0kb 'index' file to $DPBX_REQUEST_DIR folder
# - wait ~1-2 minute
# - the index file in $DPBX_REQUEST_DIR is rewritten with original full version
#
# Limitations:
# - does not support folders/subfolders at ~/Dropbox/ArchiveDrop (flat file archive only)
# - file deletion from archive can be quite tricky
# - can not sync servers with more than 2GB diff (untested, yet possible)
# - when syncing, not synced files may be randomly deleted from ~/Dropbox/ArchiveRequest
# - many files in ~/Dropbox/ArchiveRequest may degrade performance
#
# (C) 2012 Andrew Gryaznov

RUNPID=/tmp/archivebox.pid
if [ -f $RUNPID ]; then
    kill -0 $(cat $RUNPID) && exit
fi
echo -n $$ > $RUNPID
# CHANGE THESE, or make sure to have right symlinks (~/ArchiveBox -> /mnt/2TB_RAID/ArchiveBox)

LOCAL_ARCHIVE=~/ArchiveBox
DPBX_PIPE=~/Dropbox/ArchiveDrop
DPBX_INDEX_DIR=~/Dropbox/ArchiveIndex
# Dropbox dir to store and process requests (copies from $DPBX_INDEX_DIR to be converted to files)
DPBX_REQUEST_DIR=~/Dropbox/ArchiveRequest
# Also process Camera Uploads? - delete if not needed
DPBX_CAMERA_UPLOAD=~/Dropbox/Camera\ Uploads


######################################################
# automated section below


LOCAL_DEST="$LOCAL_ARCHIVE/"
mkdir $LOCAL_ARCHIVE >/dev/null 2>&1
mkdir $DPBX_PIPE >/dev/null 2>&1
mkdir $DPBX_INDEX_DIR >/dev/null 2>&1
mkdir $DPBX_REQUEST_DIR >/dev/null 2>&1

if [ ! -z "$DPBX_CAMERA_UPLOAD" ]; then
    mv -f "$DPBX_CAMERA_UPLOAD"/* $LOCAL_DEST >/dev/null 2>&1
fi


if [ ! -z "$DPBX_PIPE" ]; then
    mv -f "$DPBX_PIPE"/* $LOCAL_DEST >/dev/null 2>&1
fi

######################################################
# Create listing

CHEATWORD="RQ"

IDXFILE="/tmp/idx.archivebox"
LOCALFILE="/tmp/local.archivebox"

IFS=$'\n'
FOUND=0
CNT=0
echo "Creating index of what we have locally..."

# TODO: optimize:
# create two lists list with ls -1, 
# one list - local files
# other list - ArchiveBox index

ls -1 "$DPBX_INDEX_DIR/" > $IDXFILE
ls -1 "$LOCAL_DEST" > $LOCALFILE

# get files that are in LOCAL but not in INDEX
#EXTDIFF=$(diff $LOCALFILE $IDXFILE | grep "<" | sed 's/< //')
EXTDIFF=$(comm -23 $LOCALFILE $IDXFILE)

for FILE in $EXTDIFF; do
    echo "Doing for $FILE"
    EXT=${FILE/*./}
    ext=$(echo $EXT | tr '[A-Z]' '[a-z]')
    if [ $ext = "jpg" ]; then
        if command -v convert >/dev/null 2>&1; then
            convert "$LOCAL_DEST/$FILE" -resize 500x500 -quality 20 "$DPBX_INDEX_DIR/$FILE"
        else
            echo -n "RQ" > "$DPBX_INDEX_DIR/$FILE";
        fi
    else
        echo -n "RQ" > "$DPBX_INDEX_DIR/$FILE";
    fi
done

# clean 'conflicted copy' from index
rm $DPBX_INDEX_DIR/*conflicted\ copy*


######################################################
# Sync servers

echo "Doing sync servers..."
#RQLIST=$(ls -1 "$DPBX_REQUEST_DIR/")
#LCLIST=$(ls -1 "$LOCAL_DEST")

RQFILE="/tmp/rq.archivebox"
ABSFILE="/tmp/absent.archivebox"
#LCFILE="/tmp/lc.archivebox"

ls -1 "$DPBX_REQUEST_DIR/" > $RQFILE

# get files that are in INDEX but not in LOCAL (are ABSENT)
#diff $IDXFILE $LOCALFILE | grep "<" | sed 's/< //' > $CMPFILE
comm -23 $IDXFILE $LOCALFILE > $ABSFILE

# now get files that are absent AND in RQ
EXTDIFF=$(comm -12 $ABSFILE $RQFILE)

for FILE_IDX in $EXTDIFF; do
    # if found, check if the file is completed, then move
    if [ $(stat -c%s "$DPBX_REQUEST_DIR/$FILE_IDX") -ne $(stat -c%s "$DPBX_INDEX_DIR/$FILE_IDX") ]; then
        mv "$DPBX_REQUEST_DIR/$FILE_IDX" "$LOCAL_DEST/$FILE_IDX"
    fi
done

# now get files that are absent but not in RQ
#EXTDIFF=$(diff $CMPFILE $RQFILE | grep "<" | sed 's/< //')
EXTDIFF=$(comm -23 $ABSFILE $RQFILE)

for FILE_IDX in $EXTDIFF; do
    echo "Requesting file $FILE_IDX"
    cp "$DPBX_INDEX_DIR/$FILE_IDX" "$DPBX_REQUEST_DIR/$FILE_IDX"
done


echo "Done"

######################################################
# Fulfill file requests

for j in 1 2 3 4 5 6 7 8 9 10; do

IFS=$'\n'

for FILE in `ls -1 $DPBX_REQUEST_DIR/`; do
    # JPG way
    EXT=${FILE/*./}
    ext=$(echo $EXT | tr '[A-Z]' '[a-z]')
    if [ $ext = "jpg" ]; then
         if [ $(stat -c%s "$DPBX_REQUEST_DIR/$FILE") -lt 50000 ]; then
            # can only fulfill if file exists
            if [ -f "$LOCAL_DEST/$FILE" ]; then
                if [ $(stat -c%s "$DPBX_REQUEST_DIR/$FILE") -ne $(stat -c%s "$LOCAL_DEST/$FILE") ]; then
                    cp "$LOCAL_DEST/$FILE" "$DPBX_REQUEST_DIR/$FILE"
                fi
            fi
        fi
    else
        if [ $(stat -c%s "$DPBX_REQUEST_DIR/$FILE") -lt 5 ]; then
            if [ `cat "$DPBX_REQUEST_DIR/$FILE"` = $CHEATWORD ]; then
                if [ -f "$LOCAL_DEST/$FILE" ]; then
                    cp "$LOCAL_DEST/$FILE" "$DPBX_REQUEST_DIR/$FILE"
                fi
            fi
        fi
    fi
done

sleep 5;
done

rm $RUNPID

