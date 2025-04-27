MODPATH=${0%/*}

# log
exec 2>$MODPATH/debug.log
set -x

# var
API=`getprop ro.build.version.sdk`

# wait
until [ "`getprop sys.boot_completed`" == 1 ]; do
  sleep 10
done

# list
PKGS="`cat $MODPATH/package.txt`
      com.samsung.android.app.galaxyfinder:receiver
      com.samsung.android.app.galaxyfinder:local
      com.samsung.android.app.galaxyfinder:appservice"
for PKG in $PKGS; do
  magisk --denylist rm $PKG 2>/dev/null
  magisk --sulist add $PKG 2>/dev/null
done
if magisk magiskhide sulist; then
  for PKG in $PKGS; do
    magisk magiskhide add $PKG
  done
else
  for PKG in $PKGS; do
    magisk magiskhide rm $PKG
  done
fi

# function
appops_set() {
appops set $PKG SYSTEM_ALERT_WINDOW allow
appops set $PKG LEGACY_STORAGE allow
appops set $PKG READ_EXTERNAL_STORAGE allow
appops set $PKG WRITE_EXTERNAL_STORAGE allow
appops set $PKG READ_MEDIA_AUDIO allow
appops set $PKG READ_MEDIA_VIDEO allow
appops set $PKG READ_MEDIA_IMAGES allow
appops set $PKG WRITE_MEDIA_AUDIO allow
appops set $PKG WRITE_MEDIA_VIDEO allow
appops set $PKG WRITE_MEDIA_IMAGES allow
if [ "$API" -ge 29 ]; then
  appops set $PKG ACCESS_MEDIA_LOCATION allow
fi
if [ "$API" -ge 30 ]; then
  appops set $PKG MANAGE_EXTERNAL_STORAGE allow
  appops set $PKG NO_ISOLATED_STORAGE allow
  appops set $PKG AUTO_REVOKE_PERMISSIONS_IF_UNUSED ignore
fi
if [ "$API" -ge 31 ]; then
  appops set $PKG MANAGE_MEDIA allow
fi
if [ "$API" -ge 33 ]; then
  appops set $PKG ACCESS_RESTRICTED_SETTINGS allow
fi
if [ "$API" -ge 34 ]; then
  appops set $PKG READ_MEDIA_VISUAL_USER_SELECTED allow
fi
PKGOPS=`appops get $PKG`
UID=`dumpsys package $PKG 2>/dev/null | grep -m 1 Id= | sed -e 's|    userId=||g' -e 's|    appId=||g'`
if [ "$UID" ] && [ "$UID" -gt 9999 ]; then
  appops set --uid "$UID" LEGACY_STORAGE allow
  appops set --uid "$UID" READ_EXTERNAL_STORAGE allow
  appops set --uid "$UID" WRITE_EXTERNAL_STORAGE allow
  if [ "$API" -ge 29 ]; then
    appops set --uid "$UID" ACCESS_MEDIA_LOCATION allow
  fi
  if [ "$API" -ge 34 ]; then
    appops set --uid "$UID" READ_MEDIA_VISUAL_USER_SELECTED allow
  fi
  UIDOPS=`appops get --uid "$UID"`
fi
}

# grant
PKG=com.sec.android.app.launcher
if appops get $PKG > /dev/null 2>&1; then
  pm grant --all-permissions $PKG
  appops set $PKG GET_USAGE_STATS allow
  appops_set
fi

# grant
PKG=com.samsung.android.app.galaxyfinder
if appops get $PKG > /dev/null 2>&1; then
  pm grant --all-permissions $PKG
  appops_set
fi






