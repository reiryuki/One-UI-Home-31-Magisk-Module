# boot mode
if [ "$BOOTMODE" != true ]; then
  abort "- Please install via Magisk/KernelSU app only!"
fi

# space
ui_print " "

# var
UID=`id -u`

# log
if [ "$BOOTMODE" != true ]; then
  FILE=/data/media/"$UID"/$MODID\_recovery.log
  ui_print "- Log will be saved at $FILE"
  exec 2>$FILE
  ui_print " "
fi

# optionals
OPTIONALS=/data/media/"$UID"/optionals.prop
if [ ! -f $OPTIONALS ]; then
  touch $OPTIONALS
fi

# debug
if [ "`grep_prop debug.log $OPTIONALS`" == 1 ]; then
  ui_print "- The install log will contain detailed information"
  set -x
  ui_print " "
fi

# run
. $MODPATH/function.sh

# info
MODVER=`grep_prop version $MODPATH/module.prop`
MODVERCODE=`grep_prop versionCode $MODPATH/module.prop`
ui_print " ID=$MODID"
ui_print " Version=$MODVER"
ui_print " VersionCode=$MODVERCODE"
if [ "$KSU" == true ]; then
  ui_print " KSUVersion=$KSU_VER"
  ui_print " KSUVersionCode=$KSU_VER_CODE"
  ui_print " KSUKernelVersionCode=$KSU_KERNEL_VER_CODE"
  sed -i 's|#k||g' $MODPATH/post-fs-data.sh
else
  ui_print " MagiskVersion=$MAGISK_VER"
  ui_print " MagiskVersionCode=$MAGISK_VER_CODE"
fi
ui_print " "

# sdk
NUM=26
if [ "$API" -lt $NUM ]; then
  ui_print "! Unsupported SDK $API."
  ui_print "  You have to upgrade your Android version"
  ui_print "  at least SDK $NUM to use this module."
  abort
else
  ui_print "- SDK $API"
  ui_print " "
fi

# one ui core
if [ ! -d /data/adb/modules_update/OneUICore ]\
&& [ ! -d /data/adb/modules/OneUICore ]; then
  ui_print "! One UI Core Magisk Module is not installed."
  ui_print "  Please read github installation guide!"
  abort
else
  rm -f /data/adb/modules/OneUICore/remove
  rm -f /data/adb/modules/OneUICore/disable
fi

# recovery
mount_partitions_in_recovery

# sepolicy
FILE=$MODPATH/sepolicy.rule
DES=$MODPATH/sepolicy.pfsd
if [ "`grep_prop sepolicy.sh $OPTIONALS`" == 1 ]\
&& [ -f $FILE ]; then
  mv -f $FILE $DES
fi

# cleaning
ui_print "- Cleaning..."
PKGS=`cat $MODPATH/package.txt`
if [ "$BOOTMODE" == true ]; then
  for PKG in $PKGS; do
    FILE=`find /data/app -name *$PKG*`
    if [ "$FILE" ]; then
      RES=`pm uninstall $PKG 2>/dev/null`
    fi
  done
fi
remove_sepolicy_rule
ui_print " "

# function
conflict() {
for NAME in $NAMES; do
  DIR=/data/adb/modules_update/$NAME
  if [ -f $DIR/uninstall.sh ]; then
    sh $DIR/uninstall.sh
  fi
  rm -rf $DIR
  DIR=/data/adb/modules/$NAME
  rm -f $DIR/update
  touch $DIR/remove
  FILE=/data/adb/modules/$NAME/uninstall.sh
  if [ -f $FILE ]; then
    sh $FILE
    rm -f $FILE
  fi
  rm -rf /metadata/magisk/$NAME
  rm -rf /mnt/vendor/persist/magisk/$NAME
  rm -rf /persist/magisk/$NAME
  rm -rf /data/unencrypted/magisk/$NAME
  rm -rf /cache/magisk/$NAME
  rm -rf /cust/magisk/$NAME
done
}

# conflict
NAMES=oneuilauncher
conflict

# function
check_permission() {
if ! appops get $PKG > /dev/null 2>&1; then
  ui_print "- Checking $NAME"
  ui_print "  of $PKG..."
  FILE=`find $MODPATH/system -type f -name $APP.apk`
  RES=`pm install -g -i com.android.vending $FILE 2>/dev/null`
  if appops get $PKG > /dev/null 2>&1; then
    if ! dumpsys package $PKG | grep -q "$NAME: granted=true"; then
      ui_print "  ! You need to disable your Android Signature Verification"
      ui_print "    first to use this recents provider, otherwise it will crash."
      RES=`pm uninstall $PKG 2>/dev/null`
      RECENTS=false
      ui_print "  Changing oneui.recents to 0"
      sed -i 's|^oneui.recents=1|oneui.recents=0|g' $OPTIONALS
      sed -i 's|^one.recents=1|one.recents=0|g' $OPTIONALS
    fi
  else
    ui_print "  ! Failed."
    ui_print "    Maybe insufficient storage."
    RECENTS=false
  fi
  ui_print " "
fi
}

# desktop
FILE=$MODPATH/service.sh
if [ "`grep_prop oneui.desktop $OPTIONALS`" == 1 ]\
|| [ "`grep_prop one.desktop $OPTIONALS`" == 1 ]; then
  ui_print "- Enables desktop mode"
  sed -i 's|ro.samsung.desktop.mode 0|ro.samsung.desktop.mode 1|g' $FILE
  ui_print " "
fi

# display device type
FILE=$MODPATH/service.sh
DDT=`grep_prop oneui.ddt $OPTIONALS`
if [ ! "$DDT" ]; then
  DDT=`grep_prop one.ddt $OPTIONALS`
fi
if [ "$DDT" ]; then
  ui_print "- Sets display device type to $DDT"
  sed -i "s|ro.samsung.display.device.type 0|ro.samsung.display.device.type $DDT|g" $FILE
  ui_print " "
fi

# recents
if [ "`grep_prop oneui.recents $OPTIONALS`" == 1 ]\
|| [ "`grep_prop one.recents $OPTIONALS`" == 1 ]; then
  RECENTS=true
  if [ "$API" -lt 30 ]; then
    ui_print "- $MODNAME recents provider doesn't support the current Android version"
    RECENTS=false
    ui_print " "
  elif [ "$API" -ge 30 ] && [ "$API" -le 32 ]; then
    APP=TouchWizHome_2017
    PKG=com.sec.android.app.launcher
    NAME=android.permission.MONITOR_INPUT
    if [ "$BOOTMODE" == true ]; then
      check_permission
    fi
  fi
else
  RECENTS=false
fi
if [ "$RECENTS" == true ]; then
  NAME=*RecentsOverlay.apk
  ui_print "- $MODNAME recents provider will be activated"
  ui_print "- Quick Switch module will be disabled"
  ui_print "- Renaming any other else module $NAME"
  ui_print "  to $NAME.bak"
  touch /data/adb/modules/quickstepswitcher/disable
  touch /data/adb/modules/quickswitch/disable
  sed -i 's|#r||g' $MODPATH/post-fs-data.sh
  FILES=`find /data/adb/modules* ! -path "*/$MODID/*" -type f -name $NAME`
  for FILE in $FILES; do
    mv -f $FILE $FILE.bak
  done
  ui_print " "
else
  rm -rf $MODPATH/system/product
fi
if [ "$RECENTS" == true ] && [ ! -d /product/overlay ]; then
  ui_print "- Using /vendor/overlay/ instead of /product/overlay/"
  mv -f $MODPATH/system/product $MODPATH/system/vendor
  ui_print " "
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
PREVMODNAME=`grep_prop name $FILE`
if [ "`grep_prop data.cleanup $OPTIONALS`" == 1 ]; then
  sed -i 's|^data.cleanup=1|data.cleanup=0|g' $OPTIONALS
  ui_print "- Cleaning-up $MODID data..."
  cleanup
  ui_print " "
elif [ -d $DIR ]\
&& [ "$PREVMODNAME" != "$MODNAME" ]; then
  ui_print "- Different version detected"
  ui_print "  Cleaning-up $MODID data..."
  cleanup
  ui_print " "
fi

# function
permissive_2() {
sed -i 's|#2||g' $MODPATH/post-fs-data.sh
}
permissive() {
FILE=/sys/fs/selinux/enforce
SELINUX=`cat $FILE`
if [ "$SELINUX" == 1 ]; then
  if ! setenforce 0; then
    echo 0 > $FILE
  fi
  SELINUX=`cat $FILE`
  if [ "$SELINUX" == 1 ]; then
    ui_print "  Your device can't be turned to Permissive state."
    ui_print "  Using Magisk Permissive mode instead."
    permissive_2
  else
    if ! setenforce 1; then
      echo 1 > $FILE
    fi
    sed -i 's|#1||g' $MODPATH/post-fs-data.sh
  fi
else
  sed -i 's|#1||g' $MODPATH/post-fs-data.sh
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
for APP in $APPS; do
  REPLACE="$REPLACE
  `find $MODPATH/system -type d -name $APP | sed "s|$MODPATH||g"`/oat"
done
}

# hide
APPS="`ls $MODPATH/system/priv-app` `ls $MODPATH/system/app`"
hide_oat

# function
warning() {
ui_print "  If you are disabling this module,"
ui_print "  then you need to reinstall this module, reboot,"
ui_print "  & reinstall again to re-grant permissions."
}
warning_2() {
ui_print "  Granting permissions at the first installation"
ui_print "  doesn't work. You need to reinstall this module again"
ui_print "  after reboot to grant permissions."
}
patch_runtime_permisions() {
FILE=`find /data/system /data/misc* -type f -name runtime-permissions.xml`
chmod 0600 $FILE
if grep -q '<package name="com.sec.android.app.launcher" />' $FILE; then
  sed -i 's|<package name="com.sec.android.app.launcher" />|\
<package name="com.sec.android.app.launcher">\
<permission name="android.permission.WRITE_SETTINGS" granted="true" flags="0" />\
<permission name="android.permission.CONTROL_KEYGUARD" granted="true" flags="0" />\
<permission name="android.permission.READ_WALLPAPER_INTERNAL" granted="true" flags="0" />\
<permission name="android.permission.SET_PROCESS_LIMIT" granted="true" flags="0" />\
<permission name="com.samsung.android.launcher.permission.WRITE_SETTINGS" granted="true" flags="0" />\
<permission name="android.permission.POST_NOTIFICATIONS" granted="true" flags="0" />\
<permission name="com.samsung.android.app.appsedge.permission.OPEN_APP_PICKER" granted="true" flags="0" />\
<permission name="android.permission.MANAGE_EXTERNAL_STORAGE" granted="true" flags="0" />\
<permission name="com.samsung.android.rubin.context.permission.READ_CONTEXT_MANAGER" granted="true" flags="0" />\
<permission name="com.samsung.android.provider.indexing.permission.ACCESS_PROVIDER" granted="true" flags="0" />\
<permission name="android.permission.SYSTEM_ALERT_WINDOW" granted="true" flags="0" />\
<permission name="android.permission.START_TASKS_FROM_RECENTS" granted="true" flags="0" />\
<permission name="android.permission.MONITOR_INPUT" granted="true" flags="0" />\
<permission name="com.sec.android.app.launcher.permission.WRITE_SETTINGS" granted="true" flags="0" />\
<permission name="android.permission.CHANGE_COMPONENT_ENABLED_STATE" granted="true" flags="0" />\
<permission name="android.permission.INTERNAL_SYSTEM_WINDOW" granted="true" flags="0" />\
<permission name="com.sec.android.provider.badge.permission.READ" granted="true" flags="0" />\
<permission name="android.permission.START_ANY_ACTIVITY" granted="true" flags="0" />\
<permission name="com.samsung.android.rubin.app.ui.permission.LAUNCH_RUBIN_SETTING" granted="true" flags="0" />\
<permission name="android.permission.CALL_PRIVILEGED" granted="true" flags="0" />\
<permission name="android.permission.FOREGROUND_SERVICE" granted="true" flags="0" />\
<permission name="android.permission.READ_MEDIA_VISUAL_USER_SELECTED" granted="true" flags="0" />\
<permission name="android.permission.MANAGE_ACTIVITY_TASKS" granted="true" flags="0" />\
<permission name="android.permission.RECEIVE_BOOT_COMPLETED" granted="true" flags="0" />\
<permission name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" granted="true" flags="0" />\
<permission name="android.permission.MANAGE_ROLE_HOLDERS" granted="true" flags="0" />\
<permission name="android.permission.DEVICE_POWER" granted="true" flags="0" />\
<permission name="android.permission.REMOVE_TASKS" granted="true" flags="0" />\
<permission name="android.permission.EXPAND_STATUS_BAR" granted="true" flags="0" />\
<permission name="com.samsung.android.app.galaxyfinder.permission.ACCESS_INFO_PROVIDER" granted="true" flags="0" />\
<permission name="android.permission.ACCESS_SURFACE_FLINGER" granted="true" flags="0" />\
<permission name="android.permission.INTERNET" granted="true" flags="0" />\
<permission name="android.permission.REORDER_TASKS" granted="true" flags="0" />\
<permission name="com.android.browser.permission.READ_HISTORY_BOOKMARKS" granted="true" flags="0" />\
<permission name="android.permission.GET_INTENT_SENDER_INTENT" granted="true" flags="0" />\
<permission name="com.samsung.android.rubin.persona.permission.READ_PERSONA_MANAGER" granted="true" flags="0" />\
<permission name="android.permission.ROTATE_SURFACE_FLINGER" granted="true" flags="0" />\
<permission name="android.permission.READ_EXTERNAL_STORAGE" granted="true" flags="0" />\
<permission name="android.permission.MANAGE_ACCESSIBILITY" granted="true" flags="0" />\
<permission name="android.permission.CONTROL_REMOTE_APP_TRANSITION_ANIMATIONS" granted="true" flags="0" />\
<permission name="android.permission.USE_EXACT_ALARM" granted="true" flags="0" />\
<permission name="android.permission.INTERACT_ACROSS_USERS_FULL" granted="true" flags="0" />\
<permission name="android.permission.BIND_APPWIDGET" granted="true" flags="0" />\
<permission name="android.permission.STOP_APP_SWITCHES" granted="true" flags="0" />\
<permission name="android.permission.PACKAGE_USAGE_STATS" granted="true" flags="0" />\
<permission name="android.permission.GET_ACCOUNTS_PRIVILEGED" granted="true" flags="0" />\
<permission name="android.permission.WRITE_SECURE_SETTINGS" granted="true" flags="0" />\
<permission name="com.sec.permission.BACKUP_RESTORE_HOMESCREEN" granted="true" flags="0" />\
<permission name="android.permission.SET_ACTIVITY_WATCHER" granted="true" flags="0" />\
<permission name="android.permission.STATUS_BAR_SERVICE" granted="true" flags="0" />\
<permission name="android.permission.READ_SEARCH_INDEXABLES" granted="true" flags="0" />\
<permission name="android.permission.READ_PHONE_STATE" granted="true" flags="0" />\
<permission name="android.permission.READ_PRIVILEGED_PHONE_STATE" granted="true" flags="0" />\
<permission name="android.permission.CALL_PHONE" granted="true" flags="0" />\
<permission name="com.sec.android.app.launcher.permission.READ_SETTINGS" granted="true" flags="0" />\
<permission name="android.permission.READ_MEDIA_IMAGES" granted="true" flags="0" />\
<permission name="android.permission.ACCESS_KEYGUARD_SECURE_STORAGE" granted="true" flags="0" />\
<permission name="android.permission.INPUT_CONSUMER" granted="true" flags="0" />\
<permission name="android.permission.SET_ORIENTATION" granted="true" flags="0" />\
<permission name="android.permission.MANAGE_USERS" granted="true" flags="0" />\
<permission name="android.permission.ACCESS_NETWORK_STATE" granted="true" flags="0" />\
<permission name="android.permission.DISABLE_KEYGUARD" granted="true" flags="0" />\
<permission name="com.samsung.android.app.cocktailbarservice.permission.EDGE_HANDLER_STATE" granted="true" flags="0" />\
<permission name="android.permission.INTERACT_ACROSS_USERS" granted="true" flags="0" />\
<permission name="android.permission.SET_WALLPAPER" granted="true" flags="0" />\
<permission name="android.permission.BROADCAST_CLOSE_SYSTEM_DIALOGS" granted="true" flags="0" />\
<permission name="android.permission.READ_MEDIA_AUDIO" granted="true" flags="0" />\
<permission name="android.permission.READ_MEDIA_VIDEO" granted="true" flags="0" />\
<permission name="com.android.vending.appdiscoveryservice.permission.ACCESS_APP_DISCOVERY_SERVICE" granted="true" flags="0" />\
<permission name="com.sec.android.provider.badge.permission.WRITE" granted="true" flags="0" />\
<permission name="com.sec.android.app.launcher.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION" granted="true" flags="0" />\
<permission name="android.permission.REGISTER_STATS_PULL_ATOM" granted="true" flags="0" />\
<permission name="android.permission.ACCESS_SHORTCUTS" granted="true" flags="0" />\
<permission name="android.permission.REQUEST_DELETE_PACKAGES" granted="true" flags="0" />\
<permission name="android.permission.SUSPEND_APPS" granted="true" flags="0" />\
<permission name="android.permission.GLOBAL_SEARCH" granted="true" flags="0" />\
<permission name="android.permission.SET_WALLPAPER_HINTS" granted="true" flags="0" />\
<permission name="com.samsung.android.app.galaxyfinder.permission.ACCESS_APPLICATION_PROVIDER" granted="true" flags="0" />\
<permission name="android.permission.ALLOW_SLIPPERY_TOUCHES" granted="true" flags="0" />\
<permission name="android.permission.START_ACTIVITIES_FROM_BACKGROUND" granted="true" flags="0" />\
<permission name="android.permission.FORCE_STOP_PACKAGES" granted="true" flags="0" />\
<permission name="com.samsung.android.app.cocktailbarservice.permission.ACCESS_PANEL" granted="true" flags="0" />\
<permission name="android.permission.WRITE_EXTERNAL_STORAGE" granted="true" flags="0" />\
<permission name="android.permission.VIBRATE" granted="true" flags="0" />\
<permission name="android.permission.MANAGE_ACTIVITY_STACKS" granted="true" flags="0" />\
<permission name="android.permission.VIEW_INSTANT_APPS" granted="true" flags="0" />\
<permission name="android.permission.SET_UNRESTRICTED_GESTURE_EXCLUSION" granted="true" flags="0" />\
<permission name="android.permission.STATUS_BAR" granted="true" flags="0" />\
<permission name="android.permission.READ_FRAME_BUFFER" granted="true" flags="0" />\
<permission name="android.permission.QUERY_ALL_PACKAGES" granted="true" flags="0" />\
<permission name="android.permission.READ_DEVICE_CONFIG" granted="true" flags="0" />\
<permission name="com.samsung.android.launcher.permission.READ_SETTINGS" granted="true" flags="0" />\
<permission name="android.permission.UNLIMITED_TOASTS" granted="true" flags="0" />\
<permission name="android.permission.WAKE_LOCK" granted="true" flags="0" />\
<permission name="android.permission.READ_CONTACTS" granted="true" flags="0" />\
<permission name="android.permission.INJECT_EVENTS" granted="true" flags="0" />\
<permission name="android.permission.ACCESS_MEDIA_LOCATION" granted="true" flags="0" />\
</package>\n|g' $FILE
  warning
elif grep -q '<package name="com.sec.android.app.launcher"/>' $FILE; then
  sed -i 's|<package name="com.sec.android.app.launcher"/>|\
<package name="com.sec.android.app.launcher">\
<permission name="android.permission.WRITE_SETTINGS" granted="true" flags="0" />\
<permission name="android.permission.CONTROL_KEYGUARD" granted="true" flags="0" />\
<permission name="android.permission.READ_WALLPAPER_INTERNAL" granted="true" flags="0" />\
<permission name="android.permission.SET_PROCESS_LIMIT" granted="true" flags="0" />\
<permission name="com.samsung.android.launcher.permission.WRITE_SETTINGS" granted="true" flags="0" />\
<permission name="android.permission.POST_NOTIFICATIONS" granted="true" flags="0" />\
<permission name="com.samsung.android.app.appsedge.permission.OPEN_APP_PICKER" granted="true" flags="0" />\
<permission name="android.permission.MANAGE_EXTERNAL_STORAGE" granted="true" flags="0" />\
<permission name="com.samsung.android.rubin.context.permission.READ_CONTEXT_MANAGER" granted="true" flags="0" />\
<permission name="com.samsung.android.provider.indexing.permission.ACCESS_PROVIDER" granted="true" flags="0" />\
<permission name="android.permission.SYSTEM_ALERT_WINDOW" granted="true" flags="0" />\
<permission name="android.permission.START_TASKS_FROM_RECENTS" granted="true" flags="0" />\
<permission name="android.permission.MONITOR_INPUT" granted="true" flags="0" />\
<permission name="com.sec.android.app.launcher.permission.WRITE_SETTINGS" granted="true" flags="0" />\
<permission name="android.permission.CHANGE_COMPONENT_ENABLED_STATE" granted="true" flags="0" />\
<permission name="android.permission.INTERNAL_SYSTEM_WINDOW" granted="true" flags="0" />\
<permission name="com.sec.android.provider.badge.permission.READ" granted="true" flags="0" />\
<permission name="android.permission.START_ANY_ACTIVITY" granted="true" flags="0" />\
<permission name="com.samsung.android.rubin.app.ui.permission.LAUNCH_RUBIN_SETTING" granted="true" flags="0" />\
<permission name="android.permission.CALL_PRIVILEGED" granted="true" flags="0" />\
<permission name="android.permission.FOREGROUND_SERVICE" granted="true" flags="0" />\
<permission name="android.permission.READ_MEDIA_VISUAL_USER_SELECTED" granted="true" flags="0" />\
<permission name="android.permission.MANAGE_ACTIVITY_TASKS" granted="true" flags="0" />\
<permission name="android.permission.RECEIVE_BOOT_COMPLETED" granted="true" flags="0" />\
<permission name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" granted="true" flags="0" />\
<permission name="android.permission.MANAGE_ROLE_HOLDERS" granted="true" flags="0" />\
<permission name="android.permission.DEVICE_POWER" granted="true" flags="0" />\
<permission name="android.permission.REMOVE_TASKS" granted="true" flags="0" />\
<permission name="android.permission.EXPAND_STATUS_BAR" granted="true" flags="0" />\
<permission name="com.samsung.android.app.galaxyfinder.permission.ACCESS_INFO_PROVIDER" granted="true" flags="0" />\
<permission name="android.permission.ACCESS_SURFACE_FLINGER" granted="true" flags="0" />\
<permission name="android.permission.INTERNET" granted="true" flags="0" />\
<permission name="android.permission.REORDER_TASKS" granted="true" flags="0" />\
<permission name="com.android.browser.permission.READ_HISTORY_BOOKMARKS" granted="true" flags="0" />\
<permission name="android.permission.GET_INTENT_SENDER_INTENT" granted="true" flags="0" />\
<permission name="com.samsung.android.rubin.persona.permission.READ_PERSONA_MANAGER" granted="true" flags="0" />\
<permission name="android.permission.ROTATE_SURFACE_FLINGER" granted="true" flags="0" />\
<permission name="android.permission.READ_EXTERNAL_STORAGE" granted="true" flags="0" />\
<permission name="android.permission.MANAGE_ACCESSIBILITY" granted="true" flags="0" />\
<permission name="android.permission.CONTROL_REMOTE_APP_TRANSITION_ANIMATIONS" granted="true" flags="0" />\
<permission name="android.permission.USE_EXACT_ALARM" granted="true" flags="0" />\
<permission name="android.permission.INTERACT_ACROSS_USERS_FULL" granted="true" flags="0" />\
<permission name="android.permission.BIND_APPWIDGET" granted="true" flags="0" />\
<permission name="android.permission.STOP_APP_SWITCHES" granted="true" flags="0" />\
<permission name="android.permission.PACKAGE_USAGE_STATS" granted="true" flags="0" />\
<permission name="android.permission.GET_ACCOUNTS_PRIVILEGED" granted="true" flags="0" />\
<permission name="android.permission.WRITE_SECURE_SETTINGS" granted="true" flags="0" />\
<permission name="com.sec.permission.BACKUP_RESTORE_HOMESCREEN" granted="true" flags="0" />\
<permission name="android.permission.SET_ACTIVITY_WATCHER" granted="true" flags="0" />\
<permission name="android.permission.STATUS_BAR_SERVICE" granted="true" flags="0" />\
<permission name="android.permission.READ_SEARCH_INDEXABLES" granted="true" flags="0" />\
<permission name="android.permission.READ_PHONE_STATE" granted="true" flags="0" />\
<permission name="android.permission.READ_PRIVILEGED_PHONE_STATE" granted="true" flags="0" />\
<permission name="android.permission.CALL_PHONE" granted="true" flags="0" />\
<permission name="com.sec.android.app.launcher.permission.READ_SETTINGS" granted="true" flags="0" />\
<permission name="android.permission.READ_MEDIA_IMAGES" granted="true" flags="0" />\
<permission name="android.permission.ACCESS_KEYGUARD_SECURE_STORAGE" granted="true" flags="0" />\
<permission name="android.permission.INPUT_CONSUMER" granted="true" flags="0" />\
<permission name="android.permission.SET_ORIENTATION" granted="true" flags="0" />\
<permission name="android.permission.MANAGE_USERS" granted="true" flags="0" />\
<permission name="android.permission.ACCESS_NETWORK_STATE" granted="true" flags="0" />\
<permission name="android.permission.DISABLE_KEYGUARD" granted="true" flags="0" />\
<permission name="com.samsung.android.app.cocktailbarservice.permission.EDGE_HANDLER_STATE" granted="true" flags="0" />\
<permission name="android.permission.INTERACT_ACROSS_USERS" granted="true" flags="0" />\
<permission name="android.permission.SET_WALLPAPER" granted="true" flags="0" />\
<permission name="android.permission.BROADCAST_CLOSE_SYSTEM_DIALOGS" granted="true" flags="0" />\
<permission name="android.permission.READ_MEDIA_AUDIO" granted="true" flags="0" />\
<permission name="android.permission.READ_MEDIA_VIDEO" granted="true" flags="0" />\
<permission name="com.android.vending.appdiscoveryservice.permission.ACCESS_APP_DISCOVERY_SERVICE" granted="true" flags="0" />\
<permission name="com.sec.android.provider.badge.permission.WRITE" granted="true" flags="0" />\
<permission name="com.sec.android.app.launcher.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION" granted="true" flags="0" />\
<permission name="android.permission.REGISTER_STATS_PULL_ATOM" granted="true" flags="0" />\
<permission name="android.permission.ACCESS_SHORTCUTS" granted="true" flags="0" />\
<permission name="android.permission.REQUEST_DELETE_PACKAGES" granted="true" flags="0" />\
<permission name="android.permission.SUSPEND_APPS" granted="true" flags="0" />\
<permission name="android.permission.GLOBAL_SEARCH" granted="true" flags="0" />\
<permission name="android.permission.SET_WALLPAPER_HINTS" granted="true" flags="0" />\
<permission name="com.samsung.android.app.galaxyfinder.permission.ACCESS_APPLICATION_PROVIDER" granted="true" flags="0" />\
<permission name="android.permission.ALLOW_SLIPPERY_TOUCHES" granted="true" flags="0" />\
<permission name="android.permission.START_ACTIVITIES_FROM_BACKGROUND" granted="true" flags="0" />\
<permission name="android.permission.FORCE_STOP_PACKAGES" granted="true" flags="0" />\
<permission name="com.samsung.android.app.cocktailbarservice.permission.ACCESS_PANEL" granted="true" flags="0" />\
<permission name="android.permission.WRITE_EXTERNAL_STORAGE" granted="true" flags="0" />\
<permission name="android.permission.VIBRATE" granted="true" flags="0" />\
<permission name="android.permission.MANAGE_ACTIVITY_STACKS" granted="true" flags="0" />\
<permission name="android.permission.VIEW_INSTANT_APPS" granted="true" flags="0" />\
<permission name="android.permission.SET_UNRESTRICTED_GESTURE_EXCLUSION" granted="true" flags="0" />\
<permission name="android.permission.STATUS_BAR" granted="true" flags="0" />\
<permission name="android.permission.READ_FRAME_BUFFER" granted="true" flags="0" />\
<permission name="android.permission.QUERY_ALL_PACKAGES" granted="true" flags="0" />\
<permission name="android.permission.READ_DEVICE_CONFIG" granted="true" flags="0" />\
<permission name="com.samsung.android.launcher.permission.READ_SETTINGS" granted="true" flags="0" />\
<permission name="android.permission.UNLIMITED_TOASTS" granted="true" flags="0" />\
<permission name="android.permission.WAKE_LOCK" granted="true" flags="0" />\
<permission name="android.permission.READ_CONTACTS" granted="true" flags="0" />\
<permission name="android.permission.INJECT_EVENTS" granted="true" flags="0" />\
<permission name="android.permission.ACCESS_MEDIA_LOCATION" granted="true" flags="0" />\
</package>\n|g' $FILE
  warning
elif grep -q '<package name="com.sec.android.app.launcher">' $FILE; then
  COUNT=1
  LIST=`cat $FILE | sed 's|><|>\n<|g'`
  RES=`echo "$LIST" | grep -A$COUNT '<package name="com.sec.android.app.launcher">'`
  until echo "$RES" | grep -q '</package>'; do
    COUNT=`expr $COUNT + 1`
    RES=`echo "$LIST" | grep -A$COUNT '<package name="com.sec.android.app.launcher">'`
  done
  if ! echo "$RES" | grep -q 'name="android.permission.DEVICE_POWER" granted="true"'\
  || ! echo "$RES" | grep -q 'name="android.permission.SUSPEND_APPS" granted="true"'\
  || ! echo "$RES" | grep -q 'name="android.permission.INTERACT_ACROSS_USERS_FULL" granted="true"'; then
    PATCH=true
  else
    PATCH=false
  fi
  if [ "$PATCH" == true ]; then
    sed -i 's|<package name="com.sec.android.app.launcher">|\
<package name="com.sec.android.app.launcher">\
<permission name="android.permission.WRITE_SETTINGS" granted="true" flags="0" />\
<permission name="android.permission.CONTROL_KEYGUARD" granted="true" flags="0" />\
<permission name="android.permission.READ_WALLPAPER_INTERNAL" granted="true" flags="0" />\
<permission name="android.permission.SET_PROCESS_LIMIT" granted="true" flags="0" />\
<permission name="com.samsung.android.launcher.permission.WRITE_SETTINGS" granted="true" flags="0" />\
<permission name="android.permission.POST_NOTIFICATIONS" granted="true" flags="0" />\
<permission name="com.samsung.android.app.appsedge.permission.OPEN_APP_PICKER" granted="true" flags="0" />\
<permission name="android.permission.MANAGE_EXTERNAL_STORAGE" granted="true" flags="0" />\
<permission name="com.samsung.android.rubin.context.permission.READ_CONTEXT_MANAGER" granted="true" flags="0" />\
<permission name="com.samsung.android.provider.indexing.permission.ACCESS_PROVIDER" granted="true" flags="0" />\
<permission name="android.permission.SYSTEM_ALERT_WINDOW" granted="true" flags="0" />\
<permission name="android.permission.START_TASKS_FROM_RECENTS" granted="true" flags="0" />\
<permission name="android.permission.MONITOR_INPUT" granted="true" flags="0" />\
<permission name="com.sec.android.app.launcher.permission.WRITE_SETTINGS" granted="true" flags="0" />\
<permission name="android.permission.CHANGE_COMPONENT_ENABLED_STATE" granted="true" flags="0" />\
<permission name="android.permission.INTERNAL_SYSTEM_WINDOW" granted="true" flags="0" />\
<permission name="com.sec.android.provider.badge.permission.READ" granted="true" flags="0" />\
<permission name="android.permission.START_ANY_ACTIVITY" granted="true" flags="0" />\
<permission name="com.samsung.android.rubin.app.ui.permission.LAUNCH_RUBIN_SETTING" granted="true" flags="0" />\
<permission name="android.permission.CALL_PRIVILEGED" granted="true" flags="0" />\
<permission name="android.permission.FOREGROUND_SERVICE" granted="true" flags="0" />\
<permission name="android.permission.READ_MEDIA_VISUAL_USER_SELECTED" granted="true" flags="0" />\
<permission name="android.permission.MANAGE_ACTIVITY_TASKS" granted="true" flags="0" />\
<permission name="android.permission.RECEIVE_BOOT_COMPLETED" granted="true" flags="0" />\
<permission name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" granted="true" flags="0" />\
<permission name="android.permission.MANAGE_ROLE_HOLDERS" granted="true" flags="0" />\
<permission name="android.permission.DEVICE_POWER" granted="true" flags="0" />\
<permission name="android.permission.REMOVE_TASKS" granted="true" flags="0" />\
<permission name="android.permission.EXPAND_STATUS_BAR" granted="true" flags="0" />\
<permission name="com.samsung.android.app.galaxyfinder.permission.ACCESS_INFO_PROVIDER" granted="true" flags="0" />\
<permission name="android.permission.ACCESS_SURFACE_FLINGER" granted="true" flags="0" />\
<permission name="android.permission.INTERNET" granted="true" flags="0" />\
<permission name="android.permission.REORDER_TASKS" granted="true" flags="0" />\
<permission name="com.android.browser.permission.READ_HISTORY_BOOKMARKS" granted="true" flags="0" />\
<permission name="android.permission.GET_INTENT_SENDER_INTENT" granted="true" flags="0" />\
<permission name="com.samsung.android.rubin.persona.permission.READ_PERSONA_MANAGER" granted="true" flags="0" />\
<permission name="android.permission.ROTATE_SURFACE_FLINGER" granted="true" flags="0" />\
<permission name="android.permission.READ_EXTERNAL_STORAGE" granted="true" flags="0" />\
<permission name="android.permission.MANAGE_ACCESSIBILITY" granted="true" flags="0" />\
<permission name="android.permission.CONTROL_REMOTE_APP_TRANSITION_ANIMATIONS" granted="true" flags="0" />\
<permission name="android.permission.USE_EXACT_ALARM" granted="true" flags="0" />\
<permission name="android.permission.INTERACT_ACROSS_USERS_FULL" granted="true" flags="0" />\
<permission name="android.permission.BIND_APPWIDGET" granted="true" flags="0" />\
<permission name="android.permission.STOP_APP_SWITCHES" granted="true" flags="0" />\
<permission name="android.permission.PACKAGE_USAGE_STATS" granted="true" flags="0" />\
<permission name="android.permission.GET_ACCOUNTS_PRIVILEGED" granted="true" flags="0" />\
<permission name="android.permission.WRITE_SECURE_SETTINGS" granted="true" flags="0" />\
<permission name="com.sec.permission.BACKUP_RESTORE_HOMESCREEN" granted="true" flags="0" />\
<permission name="android.permission.SET_ACTIVITY_WATCHER" granted="true" flags="0" />\
<permission name="android.permission.STATUS_BAR_SERVICE" granted="true" flags="0" />\
<permission name="android.permission.READ_SEARCH_INDEXABLES" granted="true" flags="0" />\
<permission name="android.permission.READ_PHONE_STATE" granted="true" flags="0" />\
<permission name="android.permission.READ_PRIVILEGED_PHONE_STATE" granted="true" flags="0" />\
<permission name="android.permission.CALL_PHONE" granted="true" flags="0" />\
<permission name="com.sec.android.app.launcher.permission.READ_SETTINGS" granted="true" flags="0" />\
<permission name="android.permission.READ_MEDIA_IMAGES" granted="true" flags="0" />\
<permission name="android.permission.ACCESS_KEYGUARD_SECURE_STORAGE" granted="true" flags="0" />\
<permission name="android.permission.INPUT_CONSUMER" granted="true" flags="0" />\
<permission name="android.permission.SET_ORIENTATION" granted="true" flags="0" />\
<permission name="android.permission.MANAGE_USERS" granted="true" flags="0" />\
<permission name="android.permission.ACCESS_NETWORK_STATE" granted="true" flags="0" />\
<permission name="android.permission.DISABLE_KEYGUARD" granted="true" flags="0" />\
<permission name="com.samsung.android.app.cocktailbarservice.permission.EDGE_HANDLER_STATE" granted="true" flags="0" />\
<permission name="android.permission.INTERACT_ACROSS_USERS" granted="true" flags="0" />\
<permission name="android.permission.SET_WALLPAPER" granted="true" flags="0" />\
<permission name="android.permission.BROADCAST_CLOSE_SYSTEM_DIALOGS" granted="true" flags="0" />\
<permission name="android.permission.READ_MEDIA_AUDIO" granted="true" flags="0" />\
<permission name="android.permission.READ_MEDIA_VIDEO" granted="true" flags="0" />\
<permission name="com.android.vending.appdiscoveryservice.permission.ACCESS_APP_DISCOVERY_SERVICE" granted="true" flags="0" />\
<permission name="com.sec.android.provider.badge.permission.WRITE" granted="true" flags="0" />\
<permission name="com.sec.android.app.launcher.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION" granted="true" flags="0" />\
<permission name="android.permission.REGISTER_STATS_PULL_ATOM" granted="true" flags="0" />\
<permission name="android.permission.ACCESS_SHORTCUTS" granted="true" flags="0" />\
<permission name="android.permission.REQUEST_DELETE_PACKAGES" granted="true" flags="0" />\
<permission name="android.permission.SUSPEND_APPS" granted="true" flags="0" />\
<permission name="android.permission.GLOBAL_SEARCH" granted="true" flags="0" />\
<permission name="android.permission.SET_WALLPAPER_HINTS" granted="true" flags="0" />\
<permission name="com.samsung.android.app.galaxyfinder.permission.ACCESS_APPLICATION_PROVIDER" granted="true" flags="0" />\
<permission name="android.permission.ALLOW_SLIPPERY_TOUCHES" granted="true" flags="0" />\
<permission name="android.permission.START_ACTIVITIES_FROM_BACKGROUND" granted="true" flags="0" />\
<permission name="android.permission.FORCE_STOP_PACKAGES" granted="true" flags="0" />\
<permission name="com.samsung.android.app.cocktailbarservice.permission.ACCESS_PANEL" granted="true" flags="0" />\
<permission name="android.permission.WRITE_EXTERNAL_STORAGE" granted="true" flags="0" />\
<permission name="android.permission.VIBRATE" granted="true" flags="0" />\
<permission name="android.permission.MANAGE_ACTIVITY_STACKS" granted="true" flags="0" />\
<permission name="android.permission.VIEW_INSTANT_APPS" granted="true" flags="0" />\
<permission name="android.permission.SET_UNRESTRICTED_GESTURE_EXCLUSION" granted="true" flags="0" />\
<permission name="android.permission.STATUS_BAR" granted="true" flags="0" />\
<permission name="android.permission.READ_FRAME_BUFFER" granted="true" flags="0" />\
<permission name="android.permission.QUERY_ALL_PACKAGES" granted="true" flags="0" />\
<permission name="android.permission.READ_DEVICE_CONFIG" granted="true" flags="0" />\
<permission name="com.samsung.android.launcher.permission.READ_SETTINGS" granted="true" flags="0" />\
<permission name="android.permission.UNLIMITED_TOASTS" granted="true" flags="0" />\
<permission name="android.permission.WAKE_LOCK" granted="true" flags="0" />\
<permission name="android.permission.READ_CONTACTS" granted="true" flags="0" />\
<permission name="android.permission.INJECT_EVENTS" granted="true" flags="0" />\
<permission name="android.permission.ACCESS_MEDIA_LOCATION" granted="true" flags="0" />\
</package>\n<package name="removed">|g' $FILE
    warning
  fi
else
  warning_2
fi
}

# patch runtime-permissions.xml
ui_print "- Granting permissions"
ui_print "  Please wait..."
patch_runtime_permisions
ui_print " "






