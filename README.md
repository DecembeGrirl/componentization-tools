# 用途
用于组件自动化打包。

# 使用
## 安装
在组件根目录执行命令执行命令，通过 submodule 的方式引入此脚本
```
git submodule add https://git.quickcan.com/client_ios_devops/componentization-tools.git
```

## 使用
在组件根目录执行命令
```
sh ./componentization-tools/lib_package.sh [组件名] [版本号]
```

例如给组件 `KKPodDemo` 打包，版本号 `0.0.1`：
```
sh ./componentization-tools/lib_package.sh KKPodDemo '0.0.1'
```

## 命令参数
```
$ ./lib_package.sh -h

Usage: ./lib_package.sh [-VL] [-P <PODSPEC_REPO_NAME>] [-R <RUNNING_LOCATION>] [--] <POD_NAME> <POD_VERSION>

   POD_NAME : 打包pod名称
POD_VERSION : 打包版本号
         -P : 指定 podspec repo 的名字，默认值 kkmh-ios-spec-repo
         -V : --verbose 模式
         -R : [local|remote]，脚本运行环境，默认值 local
         -L : --use-libraries
```