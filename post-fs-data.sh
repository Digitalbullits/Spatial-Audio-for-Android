mount -o rw,remount /data
MODPATH=${0%/*}

# props
resetprop -p --delete persist.vendor.audio.spatializer.speaker_enabled
resetprop -p --delete ro.audio.spatializer_transaural_enabled_default
resetprop -p --delete ro.audio.spatializer_binaural_enabled_default
resetprop -p --delete ro.audio.spatializer_enabled
resetprop -p --delete audio.spatializer.effect.util_clamp_min
#resetprop -n persist.vendor.audio.spatializer.speaker_enabled true
resetprop -n ro.audio.spatializer_transaural_enabled_default true
resetprop -n ro.audio.spatializer_enabled true
resetprop -n audio.spatializer.effect.util_clamp_min 300
resetprop -n ro.audio.spatializer_binaural_enabled_default true
resetprop ro.audio.monitorRotation true
resetprop ro.audio.monitorWindowRotation true
#resetprop ro.vendor.audio.multichannel.5point1 true
#resetprop ro.vendor.audio.feature.spatial 7
#resetprop ro.vendor.audio.multichannel.5point1.headset true
#resetprop ro.vendor.audio.multi.channel true
#resetprop ro.vendor.audio.notify5Point1InUse true
#resetprop ro.vendor.audio.surround.support true

# log
exec 2>$MODPATH/debug-pfsd.log
set -x

# var
API=`getprop ro.build.version.sdk`
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

# run
. $MODPATH/copy.sh
. $MODPATH/.aml.sh

# permission
if [ "$API" -ge 26 ]; then
  DIRS=`find $MODPATH/vendor\
             $MODPATH/system/vendor -type d`
  for DIR in $DIRS; do
    chown 0.2000 $DIR
  done
  chcon -R u:object_r:system_lib_file:s0 $MODPATH/system/lib*
  chcon -R u:object_r:vendor_configs_file:s0 $MODPATH/system/odm/etc
  if [ -L $MODPATH/system/vendor ]\
  && [ -d $MODPATH/vendor ]; then
    chcon -R u:object_r:vendor_file:s0 $MODPATH/vendor
    chcon -R u:object_r:vendor_configs_file:s0 $MODPATH/vendor/etc
    chcon -R u:object_r:vendor_configs_file:s0 $MODPATH/vendor/odm/etc
  else
    chcon -R u:object_r:vendor_file:s0 $MODPATH/system/vendor
    chcon -R u:object_r:vendor_configs_file:s0 $MODPATH/system/vendor/etc
    chcon -R u:object_r:vendor_configs_file:s0 $MODPATH/system/vendor/odm/etc
  fi
fi

# function
mount_helper() {
if [ -d /odm ]\
&& [ "`realpath /odm/etc`" == /odm/etc ]; then
  DIR=$MODPATH/system/odm
  FILES=`find $DIR -type f -name $AUD`
  for FILE in $FILES; do
    DES=/odm`echo $FILE | sed "s|$DIR||g"`
    umount $DES
    mount -o bind $FILE $DES
  done
fi
if [ -d /my_product ]; then
  DIR=$MODPATH/system/my_product
  FILES=`find $DIR -type f -name $AUD`
  for FILE in $FILES; do
    DES=/my_product`echo $FILE | sed "s|$DIR||g"`
    umount $DES
    mount -o bind $FILE $DES
  done
fi
}

# mount
if ! grep -E 'delta|Delta|kitsune' /data/adb/magisk/util_functions.sh; then
  mount_helper
fi
