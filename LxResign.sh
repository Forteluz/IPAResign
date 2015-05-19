#!/bin/sh
#
#-------------------------------------------------------------------------------------------------
#  仅用于YK组内用于企业证书打包（如果提供给其他团队或者外部人员使用，需要删除默认证书信息！）
#  info修改的部分功能来自于 http://www.floatlearning.com/
#-------------------------------------------------------------------------------------------------
#  v1.0(beta)
#-------------------------------------------------------------------------------------------------
#  2015.5.18
#  1、去掉修改bundleId功能，以后改成参数修改项
#  2、暂时不删除临时目录，测试观察用
#-------------------------------------------------------------------------------------------------

function checkStatus {
if [ $? -ne 0 ];then
echo "ERR:出错了，打包终止。">&2
exit 1
fi
}

if [ $# -lt 3 ];
then
echo "ERR:缺少参数">&2
echo "使用说明:ipaName.ipa plistName.plist [-p name.mobileprovision] [-c certificate] [-b newAppName]"
echo "        -c 是可选参数(前提是需要修改文件，需要给CERTIFICATE赋值)"
echo "        -b 是可选参数，可以重新生成新的app名字"
echo "        (检查本地证书命令 :$ security find-identity -v -p codesigning)"
echo "        例:(如果没有权限，使用chmod +x LxResign)$:./LxResign.sh youku.ipa youku.plist -p youku.mobileprovision"
echo "        另外可以使用security cms -D -i name.mobileprovision命令查看描述信息"
exit 1
fi

#-----------------------------------------------------------------------------------------------------------------------------
echo "===========>YKIPAGo开始打包<==========="

ORIGINAL_FILE="$1"
ENTITLEMENTS="$2"
NEW_PROVISION=""
CERTIFICATE="请在这里填写证书信息，检查本地证书命令 :$ security find-identity -v -p codesigning"
TEMP_DIR="_YKIPATemp"
DISPLAY_NAME=""
TEAM_IDENTIFIER=""

echo ">打包文件:'$ORIGINAL_FILE'">&2
echo ">配置文件:'$ENTITLEMENTS'">&2

OPTIND=3
while getopts c:p:b: opt; do
case $opt in
c)
CERTIFICATE="$OPTARG"
echo ">证书:'$CERTIFICATE'">&2
;;
p)
NEW_PROVISION="$OPTARG"
echo ">mobileprovision文件:$NEW_PROVISION">&2
;;
b)
DISPLAY_NAME="$OPTARG"
echo ">新的app名字:$DISPLAY_NAME">&2
;;
\?)
echo "ERR:参数错误，请检查: -$OPTARG">&2
exit 1
;;
:)
echo "ERR:Option:-$OPTARG，参数一个都不能少">&2
exit 1
;;
esac
done

echo "----------------------------------------------------"

if [ -d "$TEMP_DIR" ]; then
echo ">删除之前的临时目录: '$TEMP_DIR'">&2
rm -Rf "$TEMP_DIR"
fi

#文件处理
filename=$(basename "$ORIGINAL_FILE")
extension="${filename##*.}"
filename="${filename%.*}"

if [ "${extension}" = "ipa" ]
then
unzip -q "$ORIGINAL_FILE" -d $TEMP_DIR
echo ">${filename}.ipa解压到临时目录$TEMP_DIR">&2
checkStatus
elif [ "${extension}" = "app" ]
then
mkdir -p "$TEMP_DIR/Payload"
cp -Rf "${ORIGINAL_FILE}" "$TEMP_DIR/Payload/${filename}.app"
echo ">当前是.app文件，拷贝到TEMP_DIR/Payload/${filename}.app目录下">&2
checkStatus
else
echo "ERR>错误，打包源文件只能是ipa或者app">&2
exit
fi

rm -rf "$TEMP_DIR/Payload/$APP_NAME/_CodeSignature/"
echo ">删除旧的_CodeSignature"

APP_NAME=$(ls "$TEMP_DIR/Payload/")

if [ ! -e "$TEMP_DIR/Payload/$APP_NAME/Info.plist" ];
then
echo "ERR>info.plist文件没找到:'$TEMP_DIR/Payload/$APP_NAME/Info.plist'">&2
exit 1;
fi

#引用本地/usr/libexec工具库
export PATH=$PATH:/usr/libexec

# 从app内读取信息
CURRENT_NAME=$(PlistBuddy -c "Print :CFBundleDisplayName" "$TEMP_DIR/Payload/$APP_NAME/Info.plist")
CURRENT_BUNDLE_IDENTIFIER=$(PlistBuddy -c "Print :CFBundleIdentifier" "$TEMP_DIR/Payload/$APP_NAME/Info.plist")

if [ "${BUNDLE_IDENTIFIER}" == "" ];
then
BUNDLE_IDENTIFIER=$(egrep -a -A 2 application-identifier "${NEW_PROVISION}" | grep string | sed -e 's/<string>//' -e 's/<\/string>//' -e 's/ //' | awk '{split($0,a,"."); i = length(a); for(ix=2; ix <= i;ix++){ s=s a[ix]; if(i!=ix){s=s "."};} print s;}')

if [[ "${BUNDLE_IDENTIFIER}" == *\** ]]; then
echo "Bundle Identifier 使用通配符 *, 不需要更换">&2
BUNDLE_IDENTIFIER=$CURRENT_BUNDLE_IDENTIFIER;
fi
checkStatus
fi

if [ "${DISPLAY_NAME}" != "" ];
then
if [ "${DISPLAY_NAME}" != "${CURRENT_NAME}" ];
then
echo ">CFBundleDisplayName '$CURRENT_NAME' 更改为 '$DISPLAY_NAME'">&2
PlistBuddy -c "Set :CFBundleDisplayName $DISPLAY_NAME" "$TEMP_DIR/Payload/$APP_NAME/Info.plist"
fi
fi

#设置信息并替换embedded.mobileprovision
if [ "$NEW_PROVISION" != "" ];then
if [[ -e "$NEW_PROVISION" ]];then
echo ">$NEW_PROVISION文件验证通过">&2
security cms -D -i "$NEW_PROVISION" > "$TEMP_DIR/profile.plist"

checkStatus

APP_IDENTIFER_PREFIX=$(PlistBuddy -c "Print :Entitlements:application-identifier" "$TEMP_DIR/profile.plist" | grep -E '^[A-Z0-9]*' -o | tr -d '\n')

if [ "$APP_IDENTIFER_PREFIX" == "" ];then
APP_IDENTIFER_PREFIX=$(PlistBuddy -c "Print :ApplicationIdentifierPrefix:0" "$TEMP_DIR/profile.plist")

if [ "$APP_IDENTIFER_PREFIX" == "" ];then
echo "ERR:Failed to extract any app identifier prefix from '$NEW_PROVISION'">&2
exit 1;
else
echo "ERR:WARNING: extracted an app identifier prefix '$APP_IDENTIFER_PREFIX' from '$NEW_PROVISION', but it was not found in the profile's entitlements" >&2
fi
else
echo ">读取appIdentifier前缀 : '$APP_IDENTIFER_PREFIX'" >&2
fi

TEAM_IDENTIFIER=$(PlistBuddy -c "Print :Entitlements:com.apple.developer.team-identifier" "$TEMP_DIR/profile.plist" | tr -d '\n')

if [ "$TEAM_IDENTIFIER" == "" ];
then
TEAM_IDENTIFIER=$(PlistBuddy -c "Print :TeamIdentifier:0" "$TEMP_DIR/profile.plist")
if [ "$TEAM_IDENTIFIER" == "" ]; then
echo "Failed to extract team identifier from '$NEW_PROVISION', resigned ipa may fail on iOS 8 and higher" >&2
else
echo "WARNING: extracted a team identifier '$TEAM_IDENTIFIER' from '$NEW_PROVISION', but it was not found in the profile's entitlements, resigned ipa may fail on iOS 8 and higher" >&2
fi
else
echo ">team 的 Profile identifier is '$TEAM_IDENTIFIER'" >&2
fi

cp "$NEW_PROVISION" "$TEMP_DIR/Payload/$APP_NAME/embedded.mobileprovision"
else
echo "ERR:Provisioning profile '$NEW_PROVISION' 文件不存在" >&2
exit 1;
fi
else
echo "-p 'xxxx.mobileprovision' 这个参数没设置！" >&2
exit 1;
fi

#更换bundle id(暂时不更换，添加到可选功能里)
#if [ "$CURRENT_BUNDLE_IDENTIFIER" != "$BUNDLE_IDENTIFIER" ];then
#    echo "Updating the bundle identifier from '$CURRENT_BUNDLE_IDENTIFIER' to '$BUNDLE_IDENTIFIER'" >&2
#    PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_IDENTIFIER" "$TEMP_DIR/Payload/$APP_NAME/Info.plist"
#    checkStatus
#fi
#echo ">当前的bundle identifier: '$CURRENT_BUNDLE_IDENTIFIER'"
#echo ">新bundle identifier: '$BUNDLE_IDENTIFIER'"

# Check for and resign any embedded frameworks (new feature for iOS 8 and above apps)
#FRAMEWORKS_DIR="$TEMP_DIR/Payload/$APP_NAME/Frameworks"
#if [ -d "$FRAMEWORKS_DIR" ];
#then
#    if [ "$TEAM_IDENTIFIER" == "" ];
#    then
#        echo "ERROR: embedded frameworks detected, re-signing iOS 8 (or higher) applications wihout a team identifier in the certificate/profile does not work" >&2
#    exit 1;
#    fi
#
#    echo "签名 embedded frameworks 使用证书: '$CERTIFICATE'" >&2
#    for framework in "$FRAMEWORKS_DIR"/*
#    do
#        if [[ "$framework" == *.framework ]];then
#            /usr/bin/codesign -f -s "$CERTIFICATE" "$framework"
#            checkStatus
#        else
#            echo ">Ignoring non-framework: $framework" >&2
#        fi
#    done
#fi

if [ "$ENTITLEMENTS" != "" ]; then
if [ -n "$APP_IDENTIFER_PREFIX" ]; then
ENTITLEMENTS_APP_ID_PREFIX=$(PlistBuddy -c "Print :application-identifier" "$ENTITLEMENTS" | grep -E '^[A-Z0-9]*' -o | tr -d '\n')

if [ "$ENTITLEMENTS_APP_ID_PREFIX" == "" ]; then
echo "ERR:Provided entitlements file is missing a value for the required 'application-identifier' key" >&2
exit 1;
elif [ "$ENTITLEMENTS_APP_ID_PREFIX" != "$APP_IDENTIFER_PREFIX" ];then
echo "ERR:entitlements文件里面的app identifier prefix '$ENTITLEMENTS_APP_ID_PREFIX'和provisioning profile's 的 '$APP_IDENTIFER_PREFIX'" >&2
exit 1;
fi
fi
fi

echo ">开始签名使用证书: '$CERTIFICATE'" >&2
echo ">还有配置文件: $ENTITLEMENTS" >&2
/usr/bin/codesign -f -s "$CERTIFICATE" --entitlements="$ENTITLEMENTS" "$TEMP_DIR/Payload/$APP_NAME"

checkStatus

pushd "$TEMP_DIR" > /dev/null
zip -qr "../$TEMP_DIR.ipa" ./*
popd > /dev/null

#rm -rf "$TEMP_DIR"

echo ">===================>打包完成<===================" >&2
