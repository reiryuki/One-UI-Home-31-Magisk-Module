mount -o rw,remount /data
MODPATH=${0%/*}

# log
exec 2>$MODPATH/debug-pfsd.log
set -x

# var
ABI=`getprop ro.product.cpu.abi`

# function
permissive() {
if [ "$SELINUX" == Enforcing ]; then
  if ! setenforce 0; then
    echo 0 > /sys/fs/selinux/enforce
  fi
fi
}
magisk_permissive() {
if [ "$SELINUX" == Enforcing ]; then
  if [ -x "`command -v magiskpolicy`" ]; then
	magiskpolicy --live "permissive *"
  else
	$MODPATH/$ABI/libmagiskpolicy.so --live "permissive *"
  fi
fi
}
sepolicy_sh() {
if [ -f $FILE ]; then
  if [ -x "`command -v magiskpolicy`" ]; then
    magiskpolicy --live --apply $FILE 2>/dev/null
  else
    $MODPATH/$ABI/libmagiskpolicy.so --live --apply $FILE 2>/dev/null
  fi
fi
}

# selinux
SELINUX=`getenforce`
chmod 0755 $MODPATH/*/libmagiskpolicy.so
#1permissive
#2magisk_permissive
#kFILE=$MODPATH/sepolicy.rule
#ksepolicy_sh
FILE=$MODPATH/sepolicy.pfsd
sepolicy_sh

# list
(
PKGS="`cat $MODPATH/package.txt`
      com.samsung.android.app.galaxyfinder:receiver
      com.samsung.android.app.galaxyfinder:local
      com.samsung.android.app.galaxyfinder:appservice"
for PKG in $PKGS; do
  magisk --denylist rm $PKG
  magisk --sulist add $PKG
done
FILE=$MODPATH/tmp_file
magisk --hide sulist 2>$FILE
if [ "`cat $FILE`" == 'SuList is enforced' ]; then
  for PKG in $PKGS; do
    magisk --hide add $PKG
  done
else
  for PKG in $PKGS; do
    magisk --hide rm $PKG
  done
fi
rm -f $FILE
) 2>/dev/null

# conflict
#rtouch /data/adb/modules/quickstepswitcher/disable
#rtouch /data/adb/modules/quickswitch/disable

# permission
DIRS=`find $MODPATH/vendor\
           $MODPATH/system/vendor -type d`
for DIR in $DIRS; do
  chown 0.2000 $DIR
done
if [ -L $MODPATH/system/product ]\
&& [ -d $MODPATH/product ]; then
  chcon -R u:object_r:vendor_overlay_file:s0 $MODPATH/product/overlay
else
  chcon -R u:object_r:vendor_overlay_file:s0 $MODPATH/system/product/overlay
fi
if [ -L $MODPATH/system/vendor ]\
&& [ -d $MODPATH/vendor ]; then
  chcon -R u:object_r:vendor_file:s0 $MODPATH/vendor
  chcon -R u:object_r:vendor_overlay_file:s0 $MODPATH/vendor/overlay
else
  chcon -R u:object_r:vendor_file:s0 $MODPATH/system/vendor
  chcon -R u:object_r:vendor_overlay_file:s0 $MODPATH/system/vendor/overlay
fi

# cleaning
FILE=$MODPATH/cleaner.sh
if [ -f $FILE ]; then
  . $FILE
  mv -f $FILE $FILE\.txt
fi








