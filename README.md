archivebox
==========

DropBox extension (shell script) to manage unlimited space file archive on your home computer

 ArchiveBox: Dropbox extended archive v.0.2b
 Ever thought of unnesessary files in your Dropbox? Have 24/7-running PCs?
                 Or at least PCs with overlapping run time?
                               Haz linuxz?
 With this script running, when you move/copy files to ~/Dropbox/ArchiveDrop folder,
 the files get moved to ~/ArchiveBox folder (outside of Dropbox). Also an index
 is created at ~/Dropbox/ArchiveIndex with empty files (or previews for jpg).
 When you copy/move an index file to ~/Dropbox/ArchiveRequest, it is rewritten
 by a script with real file. That's it! Works with all clients, including mobile,
 is able to synchronize ArchiveBox with many computers. Also processes
 'Camera Uploads' folder the same way as ArchiveDrop.

 Requirements:
 - modern linux distro with Dropbox (Mac may work too)
 - convert utility from ImageMagick

 Script installation:
 - (optional) change directories to whatever you like below
 - add this string to crontab (crontab -e) on all machines you want to sync:
   "* * * * * ~/archivebox.sh"
 where ~/archivebox.sh is a full path to this script
 - wait for 1 minute, check if the script is running:
  ps aux | grep archivebox

 Archive usage:
 - all moved files appear in $DPBX_INDEX_DIR with 0kb file size (2 bytes to be correct)
 - you copy or move(it will be re-created anyway) a 0kb 'index' file to $DPBX_REQUEST_DIR folder
 - wait ~1-2 minute
 - the index file in $DPBX_REQUEST_DIR is rewritten with original full version

 Limitations:
 - does not support folders/subfolders at ~/Dropbox/ArchiveDrop (flat file archive only)
 - file deletion from archive can be quite tricky
 - can not sync servers with more than 2GB diff (untested, yet possible)
 - when syncing, not synced files may be randomly deleted from ~/Dropbox/ArchiveRequest
 - many files in ~/Dropbox/ArchiveRequest may degrade performance

 (C) 2012 Andrew Gryaznov

