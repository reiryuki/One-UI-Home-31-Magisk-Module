[ "$MODPATH" ] && MODPATH=${0%/*}
UID=`id -u`

# cleaning
APPS="`ls $MODPATH/system/priv-app` `ls $MODPATH/system/app`"
for APP in $APPS; do
  rm -f `find /data/system/package_cache -type f -name *$APP*`
  rm -f `find /data/dalvik-cache /data/resource-cache -type f -name *$APP*.apk`
done
PKGS=`cat $MODPATH/package.txt`
for PKG in $PKGS; do
  rm -rf /data/user*/"$UID"/$PKG/cache/*
done






