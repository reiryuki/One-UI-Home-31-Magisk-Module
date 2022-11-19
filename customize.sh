# space
if [ "$BOOTMODE" == true ]; then
  ui_print " "
fi

# magisk
if [ -d /sbin/.magisk ]; then
  MAGISKTMP=/sbin/.magisk
else
  MAGISKTMP=`realpath /dev/*/.magisk`
fi

# path
if [ "$BOOTMODE" == true ]; then
  MIRROR=$MAGISKTMP/mirror
else
  MIRROR=
fi
SYSTEM=`realpath $MIRROR/system`
PRODUCT=`realpath $MIRROR/product`
VENDOR=`realpath $MIRROR/vendor`
SYSTEM_EXT=`realpath $MIRROR/system/system_ext`
ODM=`realpath /odm`
MY_PRODUCT=`realpath /my_product`

# optionals
OPTIONALS=/sdcard/optionals.prop

# info
MODVER=`grep_prop version $MODPATH/module.prop`
MODVERCODE=`grep_prop versionCode $MODPATH/module.prop`
ui_print " ID=$MODID"
ui_print " Version=$MODVER"
ui_print " VersionCode=$MODVERCODE"
ui_print " MagiskVersion=$MAGISK_VER"
ui_print " MagiskVersionCode=$MAGISK_VER_CODE"
ui_print " "

# sdk
NUM=26
if [ "$API" -lt $NUM ]; then
  ui_print "! Unsupported SDK $API."
  ui_print "  You have to upgrade your Android version"
  ui_print "  at least SDK API $NUM to use this module."
  abort
else
  ui_print "- SDK $API"
  ui_print " "
fi

# mount
if [ "$BOOTMODE" != true ]; then
  mount -o rw -t auto /dev/block/bootdevice/by-name/cust /vendor
  mount -o rw -t auto /dev/block/bootdevice/by-name/vendor /vendor
  mount -o rw -t auto /dev/block/bootdevice/by-name/persist /persist
  mount -o rw -t auto /dev/block/bootdevice/by-name/metadata /metadata
fi

# sepolicy.rule
FILE=$MODPATH/sepolicy.sh
DES=$MODPATH/sepolicy.rule
if [ -f $FILE ] && [ "`grep_prop sepolicy.sh $OPTIONALS`" != 1 ]; then
  mv -f $FILE $DES
  sed -i 's/magiskpolicy --live "//g' $DES
  sed -i 's/"//g' $DES
fi

# cleaning
ui_print "- Cleaning..."
PKG="com.sec.android.app.launcher
     com.sec.android.provider.badge
     com.samsung.android.rubin.app
     com.samsung.android.app.galaxyfinder
     com.sec.android.settings
     com.android.settings.intelligence
     com.samsung.android.app.appsedge
     org.blinksd.settings"
if [ "$BOOTMODE" == true ]; then
  for PKGS in $PKG; do
    RES=`pm uninstall $PKGS`
  done
fi
rm -rf /metadata/magisk/$MODID
rm -rf /mnt/vendor/persist/magisk/$MODID
rm -rf /persist/magisk/$MODID
rm -rf /data/unencrypted/magisk/$MODID
rm -rf /cache/magisk/$MODID
ui_print " "

# function
conflict() {
for NAMES in $NAME; do
  DIR=/data/adb/modules_update/$NAMES
  if [ -f $DIR/uninstall.sh ]; then
    sh $DIR/uninstall.sh
  fi
  rm -rf $DIR
  DIR=/data/adb/modules/$NAMES
  rm -f $DIR/update
  touch $DIR/remove
  FILE=/data/adb/modules/$NAMES/uninstall.sh
  if [ -f $FILE ]; then
    sh $FILE
    rm -f $FILE
  fi
  rm -rf /metadata/magisk/$NAMES
  rm -rf /mnt/vendor/persist/magisk/$NAMES
  rm -rf /persist/magisk/$NAMES
  rm -rf /data/unencrypted/magisk/$NAMES
  rm -rf /cache/magisk/$NAMES
done
}

# recents
if [ "`grep_prop one.recents $OPTIONALS`" == 1 ]; then
  RECENTS=true
  if [ "$API" == 30 ] || [ "$API" == 29 ]; then
    ui_print "- Using legacy $MODNAME version"
    cp -rf $MODPATH/system_11/* $MODPATH/system
    ui_print " "
  elif [ "$API" -le 28 ] || [ "$API" -ge 33 ]; then
    ui_print "- $MODNAME recents provider doesn't support the current Android version"
    RECENTS=false
    ui_print " "
  fi
else
  RECENTS=false
fi
rm -rf $MODPATH/system_11

# conflict
NAME=oneuilauncher
conflict
if [ "$RECENTS" == true ]; then
  ui_print "- $MODNAME recents provider will be activated"
  ui_print "  Quick Switch module will be disabled"
  touch /data/adb/modules/quickstepswitcher/disable
  touch /data/adb/modules/quickswitch/disable
  sed -i 's/#r//g' $MODPATH/post-fs-data.sh
  ui_print " "
else
  rm -rf $MODPATH/system/product
fi

# function
cleanup() {
if [ -f $DIR/uninstall.sh ]; then
  sh $DIR/uninstall.sh
fi
DIR=/data/adb/modules_update/$MODID
if [ -f $DIR/uninstall.sh ]; then
  sh $DIR/uninstall.sh
fi
}

# cleanup
DIR=/data/adb/modules/$MODID
FILE=$DIR/module.prop
if [ "`grep_prop data.cleanup $OPTIONALS`" == 1 ]; then
  sed -i 's/^data.cleanup=1/data.cleanup=0/' $OPTIONALS
  ui_print "- Cleaning-up $MODID data..."
  cleanup
  ui_print " "
elif [ -d $DIR ] && ! grep -Eq "$MODNAME" $FILE; then
  ui_print "- Different version detected"
  ui_print "  Cleaning-up $MODID data..."
  cleanup
  ui_print " "
fi

# function
permissive_2() {
sed -i '1i\
SELINUX=`getenforce`\
if [ "$SELINUX" == Enforcing ]; then\
  magiskpolicy --live "permissive *"\
fi\' $MODPATH/post-fs-data.sh
}
permissive() {
SELINUX=`getenforce`
if [ "$SELINUX" == Enforcing ]; then
  setenforce 0
  SELINUX=`getenforce`
  if [ "$SELINUX" == Enforcing ]; then
    ui_print "  Your device can't be turned to Permissive state."
    ui_print "  Using Magisk Permissive mode instead."
    permissive_2
  else
    setenforce 1
    sed -i '1i\
SELINUX=`getenforce`\
if [ "$SELINUX" == Enforcing ]; then\
  setenforce 0\
fi\' $MODPATH/post-fs-data.sh
  fi
fi
}

# permissive
if [ "`grep_prop permissive.mode $OPTIONALS`" == 1 ]; then
  ui_print "- Using device Permissive mode."
  rm -f $MODPATH/sepolicy.rule
  permissive
  ui_print " "
elif [ "`grep_prop permissive.mode $OPTIONALS`" == 2 ]; then
  ui_print "- Using Magisk Permissive mode."
  rm -f $MODPATH/sepolicy.rule
  permissive_2
  ui_print " "
fi

# function
hide_oat() {
for APPS in $APP; do
  mkdir -p `find $MODPATH/system -type d -name $APPS`/oat
  touch `find $MODPATH/system -type d -name $APPS`/oat/.replace
done
}
replace_dir() {
if [ -d $DIR ]; then
  mkdir -p $MODDIR
  touch $MODDIR/.replace
fi
}
hide_app() {
DIR=$SYSTEM/app/$APPS
MODDIR=$MODPATH/system/app/$APPS
replace_dir
DIR=$SYSTEM/priv-app/$APPS
MODDIR=$MODPATH/system/priv-app/$APPS
replace_dir
DIR=$PRODUCT/app/$APPS
MODDIR=$MODPATH/system/product/app/$APPS
replace_dir
DIR=$PRODUCT/priv-app/$APPS
MODDIR=$MODPATH/system/product/priv-app/$APPS
replace_dir
DIR=$MY_PRODUCT/app/$APPS
MODDIR=$MODPATH/system/product/app/$APPS
replace_dir
DIR=$MY_PRODUCT/priv-app/$APPS
MODDIR=$MODPATH/system/product/priv-app/$APPS
replace_dir
DIR=$PRODUCT/preinstall/$APPS
MODDIR=$MODPATH/system/product/preinstall/$APPS
replace_dir
DIR=$SYSTEM_EXT/app/$APPS
MODDIR=$MODPATH/system/system_ext/app/$APPS
replace_dir
DIR=$SYSTEM_EXT/priv-app/$APPS
MODDIR=$MODPATH/system/system_ext/priv-app/$APPS
replace_dir
DIR=$VENDOR/app/$APPS
MODDIR=$MODPATH/system/vendor/app/$APPS
replace_dir
DIR=$VENDOR/euclid/product/app/$APPS
MODDIR=$MODPATH/system/vendor/euclid/product/app/$APPS
replace_dir
}

# hide
APP="`ls $MODPATH/system/priv-app` `ls $MODPATH/system/app`"
hide_oat
APP=SettingsIntelligence
for APPS in $APP; do
  hide_app
done







