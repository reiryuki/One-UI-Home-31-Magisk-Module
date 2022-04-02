# type
magiskpolicy --live "type vendor_overlay_file"

# dir
magiskpolicy --live "dontaudit { system_app priv_app platform_app untrusted_app_29 untrusted_app_27 untrusted_app } { blkio_dev sysfs_batteryinfo } dir search"
magiskpolicy --live "allow     { system_app priv_app platform_app untrusted_app_29 untrusted_app_27 untrusted_app } { blkio_dev sysfs_batteryinfo } dir search"


