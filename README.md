# IPAResign

##使用说明
```shell
./file.sh ipaName.ipa plistName.plist [-p name.mobileprovision] [-c certificate] [-b newAppName]<br>
```
-c 是可选参数(前提是需要修改文件，需要给CERTIFICATE赋值)<br>
-b 是可选参数，可以重新生成新的app名字<br>
(检查本地证书命令 :$ security find-identity -v -p codesigning)<br>
例:(如果没有权限，使用chmod +x LxResign)$:./LxResign.sh youku.ipa youku.plist -p youku.mobileprovision<br>
另外可以使用security cms -D -i name.mobileprovision命令查看描述信息<br>
