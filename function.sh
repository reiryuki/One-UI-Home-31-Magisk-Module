# function
remove_cache() {
FILES=`find $MODPATH -type f -name *.apk | sed 's|.apk||g'`
APPS=`for FILE in $FILES; do basename $FILE; done`
for APP in $APPS; do
  rm -f `find /data/system/package_cache\
   /data/dalvik-cache /data/resource-cache\
   -type f -name *$APP*`
done
}
apex_list() {
APXS=`ls -dp /apex/* | grep '/$' | sed -e 's|/$||' -e 's|^/apex/sharedlibs$||'`
}
mount_partitions_in_recovery() {
if [ "$BOOTMODE" != true ]; then
  BLOCK=/dev/block/bootdevice/by-name
  BLOCK2=/dev/block/mapper
  ui_print "- Recommended to mount all partitions first"
  ui_print "  before installing this module"
  ui_print " "
  DIR=/vendor
  if [ -d $DIR ] && ! is_mounted $DIR; then
    mount -o rw -t auto $BLOCK$DIR$SLOT $DIR\
    || mount -o rw -t auto $BLOCK2$DIR$SLOT $DIR\
    || mount -o rw -t auto $BLOCK/cust $DIR\
    || mount -o rw -t auto $BLOCK2/cust $DIR
  fi
  DIRS="/product /system_ext /odm"
  for DIR in $DIRS; do
    if [ -d $DIR ] && ! is_mounted $DIR; then
      mount -o rw -t auto $BLOCK$DIR$SLOT $DIR\
      || mount -o rw -t auto $BLOCK2$DIR$SLOT $DIR
    fi
  done
#  apex_list
  DIRS="/my_product /cache /persist /metadata /cust /klogdump
        $APXS"
  for DIR in $DIRS; do
    if [ -d $DIR ] && ! is_mounted $DIR; then
      mount -o rw -t auto $BLOCK$DIR $DIR\
      || mount -o rw -t auto $BLOCK2$DIR $DIR
    fi
  done
  DIR=/data
  if [ -d $DIR ] && ! is_mounted $DIR; then
    mount -o rw -t auto $BLOCK/userdata $DIR\
    || mount -o rw -t auto $BLOCK2/userdata $DIR
  fi
fi
}
remove_sepolicy_rule() {
rm -rf /metadata/magisk/"$MODID"\
 /mnt/vendor/persist/magisk/"$MODID"\
 /persist/magisk/"$MODID"\
 /data/unencrypted/magisk/"$MODID"\
 /cache/magisk/"$MODID"\
 /cust/magisk/"$MODID"\
 /klogdump/magisk/"$MODID"
}


