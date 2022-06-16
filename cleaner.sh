MODPATH=${0%/*}
APP="`ls $MODPATH/system/priv-app` `ls $MODPATH/system/app`"
for APPS in $APP; do
  rm -f `find /data/dalvik-cache /data/resource-cache -type f -name *$APPS*.apk`
done
PKG="com.sec.android.app.launcher*
     com.sec.android.provider.badge
     com.samsung.android.rubin.app
     com.samsung.android.app.galaxyfinder
     com.sec.android.settings
     com.android.settings.intelligence
     com.samsung.android.app.appsedge"
for PKGS in $PKG; do
  rm -rf /data/user/*/$PKGS/cache/*
done


