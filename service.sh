MODPATH=${0%/*}

# log
exec 2>$MODPATH/debug.log
set -x

# var
API=`getprop ro.build.version.sdk`

# property
if [ "$API" == 26 ]; then
  resetprop ro.build.version.sem 2601
  resetprop ro.build.version.sep 90000
elif [ "$API" == 27 ]; then
  resetprop ro.build.version.sem 2701
  resetprop ro.build.version.sep 90500
elif [ "$API" == 28 ]; then
  resetprop ro.build.version.sem 2801
  resetprop ro.build.version.sep 100000
elif [ "$API" == 29 ]; then
  resetprop ro.build.version.sem 2903
  resetprop ro.build.version.sep 110500
elif [ "$API" == 30 ]; then
  resetprop ro.build.version.sem 3002
  resetprop ro.build.version.sep 120500
elif [ "$API" == 31 ]; then
  resetprop ro.build.version.sem 3101
  resetprop ro.build.version.sep 130000
elif [ "$API" == 32 ]; then
  resetprop ro.build.version.sem 3201
  resetprop ro.build.version.sep 130000 # estimate
elif [ "$API" == 33 ]; then
  resetprop ro.build.version.sem 3301
  resetprop ro.build.version.sep 140100
elif [ "$API" -ge 34 ]; then
  resetprop ro.build.version.sem 3401 # estimate
  resetprop ro.build.version.sep 150100 # estimate
fi
resetprop ro.product_ship true
resetprop ro.samsung.desktop.mode 0
resetprop ro.samsung.display.device.type 0

# wait
until [ "`getprop sys.boot_completed`" == "1" ]; do
  sleep 10
done

# function
grant_permission() {
pm grant $PKG android.permission.READ_EXTERNAL_STORAGE
pm grant $PKG android.permission.WRITE_EXTERNAL_STORAGE
if [ "$API" -ge 29 ]; then
  pm grant $PKG android.permission.ACCESS_MEDIA_LOCATION 2>/dev/null
  appops set $PKG ACCESS_MEDIA_LOCATION allow
fi
if [ "$API" -ge 33 ]; then
  pm grant $PKG android.permission.READ_MEDIA_AUDIO
  pm grant $PKG android.permission.READ_MEDIA_VIDEO
  pm grant $PKG android.permission.READ_MEDIA_IMAGES
  appops set $PKG ACCESS_RESTRICTED_SETTINGS allow
fi
appops set $PKG LEGACY_STORAGE allow
appops set $PKG READ_EXTERNAL_STORAGE allow
appops set $PKG WRITE_EXTERNAL_STORAGE allow
appops set $PKG READ_MEDIA_AUDIO allow
appops set $PKG READ_MEDIA_VIDEO allow
appops set $PKG READ_MEDIA_IMAGES allow
appops set $PKG WRITE_MEDIA_AUDIO allow
appops set $PKG WRITE_MEDIA_VIDEO allow
appops set $PKG WRITE_MEDIA_IMAGES allow
if [ "$API" -ge 30 ]; then
  appops set $PKG MANAGE_EXTERNAL_STORAGE allow
  appops set $PKG NO_ISOLATED_STORAGE allow
  appops set $PKG AUTO_REVOKE_PERMISSIONS_IF_UNUSED ignore
fi
if [ "$API" -ge 31 ]; then
  appops set $PKG MANAGE_MEDIA allow
fi
PKGOPS=`appops get $PKG`
UID=`dumpsys package $PKG 2>/dev/null | grep -m 1 userId= | sed 's|    userId=||g'`
if [ "$UID" -gt 9999 ]; then
  appops set --uid "$UID" LEGACY_STORAGE allow
  if [ "$API" -ge 29 ]; then
    appops set --uid "$UID" ACCESS_MEDIA_LOCATION allow
  fi
  UIDOPS=`appops get --uid "$UID"`
fi
}

# grant
PKG=com.sec.android.app.launcher
appops set $PKG SYSTEM_ALERT_WINDOW allow
appops set $PKG GET_USAGE_STATS allow
pm grant $PKG android.permission.READ_PHONE_STATE
pm grant $PKG android.permission.CALL_PHONE
pm grant $PKG android.permission.READ_CONTACTS
if [ "$API" -ge 33 ]; then
  appops set $PKG ACCESS_RESTRICTED_SETTINGS allow
fi
if [ "$API" -ge 30 ]; then
  appops set $PKG AUTO_REVOKE_PERMISSIONS_IF_UNUSED ignore
fi
PKGOPS=`appops get $PKG`
UID=`dumpsys package $PKG 2>/dev/null | grep -m 1 userId= | sed 's|    userId=||g'`
if [ "$UID" -gt 9999 ]; then
  UIDOPS=`appops get --uid "$UID"`
fi

# grant
PKG=com.samsung.android.rubin.app
#pm grant $PKG android.permission.READ_SMS
#pm grant $PKG android.permission.READ_CALL_LOG
pm grant $PKG android.permission.READ_CALENDAR
pm grant $PKG android.permission.ACCESS_FINE_LOCATION
pm grant $PKG android.permission.ACCESS_COARSE_LOCATION
#pm grant $PKG android.permission.PROCESS_OUTGOING_CALLS
pm grant $PKG android.permission.GET_ACCOUNTS
pm grant $PKG android.permission.ACTIVITY_RECOGNITION
pm grant $PKG android.permission.ACCESS_BACKGROUND_LOCATION
pm grant $PKG android.permission.READ_CONTACTS
grant_permission

# grant
PKG=com.samsung.android.app.galaxyfinder
pm grant $PKG android.permission.ACCESS_FINE_LOCATION
pm grant $PKG android.permission.ACCESS_COARSE_LOCATION
pm grant $PKG android.permission.READ_CONTACTS
appops set $PKG SYSTEM_ALERT_WINDOW allow
grant_permission

















