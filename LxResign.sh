#!/bin/sh

#
ENTITLEMENTS=entitlements.plist

#
CERTIFICATE_NAME="iPhone Distribution: 1 Verge Information Technology Co., Ltd."

#
IPA_NAME=${1%.ipa}

#
MOBILE_PROVISION_NAME=${2%.mobileprovision}


if [ "$IPA_NAME" = "$1" ]; then
    echo \"${1}\"不是ipa文件
    exit
fi

#解压到当前目录
unzip ${IPA_NAME}.ipa

#移除 _CodeSignature
rm -rf Payload/*.app/_CodeSignature/

#替换embedded.mobileprovision
cp ${MOBILE_PROVISION_NAME}.mobileprovision Payload/*.app/embedded.mobileprovision

#签名
(/usr/bin/codesign -f -s "$CERTIFICATE_NAME" --entitlements entitlements.plist Payload/${IPA_NAME}.app) || {
    echo failed
    rm -rf Payload/
    rm -rf SwiftSupport/
    exit
}

echo \"${IPA_NAME}\"

#重打包
zip -r ${IPA_NAME}_YKInhouse.ipa Payload

#删除
rm -rf Payload/
rm -rf SwiftSupport/


#xcrun -sdk iphoneos PackageApplication -v "Payload/MeiDian.app" -o "MeiDianXcrun.ipa" --sign "#CERTIFICATE_NAME" --embed "$MOBILE_PROVISION_NAME.mobileprovision"  > codeSign.log
