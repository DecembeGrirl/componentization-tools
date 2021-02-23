#!/bin/sh

# Show commands
# set -x

print_help() {
	echo
	echo "Usage: ./lib_package.sh [-VL] [-P <PODSPEC_REPO_NAME>] [-R <RUNNING_LOCATION>] [--] <POD_NAME> <POD_VERSION>"
	echo
	echo "   POD_NAME : 打包pod名称"
	echo "POD_VERSION : 打包版本号"
	echo "         -P : 指定 podspec repo 的名字，默认值 kkmh-ios-spec-repo"
	echo "         -V : --verbose 模式"
	echo "         -R : [local|remote]，脚本运行环境，默认值 local"
	echo "         -L : --use-libraries"
	echo
}

ARGS=`getopt hP:VRL $*`
if [ $? != 0 ]; then
    exit 1
fi

set -- $ARGS

while true; do
	case "$1" in
		-h)
			print_help
			exit 0
			;;
		-P)
			PODSPEC_REPO_NAME=$2
			shift 2
			;;
		-V)
			VERBOSE_OUTPUT='--verbose'
			shift
			;;
		-R)
			RUNNING_LOCATION=$2
			shift 2
			;;
		-L)
			USE_LIBRARIES='--use-libraries'
			shift
			;;
		--)
			shift
			break
			;;
	esac
done

# CocoaPods 版本号
pod --version

# 脚本运行环境，remote=持续集成，local=本地，默认local
RUNNING_LOCATION=${RUNNING_LOCATION:-"local"}

# Pod 组件名，外部传入
POD_NAME=$1
echo "pod name: ${POD_NAME}"

# Pod 组件版本号，外部传入
POD_VERSION=$2
echo "tag name: ${POD_VERSION}"

# Podspec 仓库名，外部传入，不传则使用默认仓库名
PODSPEC_REPO_NAME=${PODSPEC_REPO_NAME:-"kkmh-ios-spec-repo"}
PODSPEC_REPO_URL=https://git.quickcan.com/client-ios-spec-repo/kkmh-ios-spec-repo
echo "podspec repo name: $PODSPEC_REPO_NAME"
echo "podspec repo url: $PODSPEC_REPO_URL"

# podspec 文件名
PODSPEC_NAME=$POD_NAME.podspec
echo "podspec name: $PODSPEC_NAME"

# 打包用的 tag
PACKAGE_TAG_SUFFIX=-source
PACKAGE_TAG_NAME=$POD_VERSION$PACKAGE_TAG_SUFFIX
echo "package tag name: $PACKAGE_TAG_NAME"

print_error() {
	echo
	echo "Kuaikan Package Failed:" "$1"
	echo
}

# 验证版本号
tag=$(git tag -l | grep "$POD_VERSION")
if [ -n "$tag" ]; then
	print_error "此版本($POD_VERSION)的 tag 已存在 ($tag), 请删除已有 tag 后再试"
	exit 1
fi

# lint
PACKAGING=$PACKAGE_TAG_SUFFIX pod lib lint ${PODSPEC_NAME} \
	--allow-warnings \
	--sources=$PODSPEC_REPO_URL \
	--subspec=source \
	${USE_LIBRARIES} \
	${VERBOSE_OUTPUT}

if [ $? -ne 0 ]; then
	print_error "pod lib lint"
    exit 1
fi

# 更新 podspec 文件里的版本号
# 替换形如 s.version     =    '0.1.0' 中的版本号
sed -i "" "s/^\( *s\.version *= *\)'.*'$/\1'$POD_VERSION'/g" ./$PODSPEC_NAME

# commit & push & tag
git add .
git commit -m "update version of podspec to $POD_VERSION"
git tag "$PACKAGE_TAG_NAME"
git push
git push --tags

# push version for packaging to remote spec-repo
PACKAGING=$PACKAGE_TAG_SUFFIX pod repo push $PODSPEC_REPO_NAME $PODSPEC_NAME \
	--sources=$PODSPEC_REPO_URL \
	${USE_LIBRARIES} \
	--allow-warnings \
	${VERBOSE_OUTPUT}

if [ $? -ne 0 ]; then
	print_error "pod repo push"
    exit 1
fi

# 打包产出路径
OUTPUT_DIR=./$POD_NAME-$POD_VERSION

# 清空打包产出路径
rm -rf $OUTPUT_DIR

# package
PACKAGING=$PACKAGE_TAG_SUFFIX pod package $PODSPEC_NAME \
	--spec-sources=$PODSPEC_REPO_URL \
	--force \
	--embedded \
	--no-mangle \
	--exclude-deps \
	--subspecs=source \
	${VERBOSE_OUTPUT}

if [ $? -ne 0 ]; then
	print_error "pod package"
	rm -rf $OUTPUT_DIR
    exit 1
fi

# framework路径
FRAMEWORK_OUTPUT_PATH=$OUTPUT_DIR/ios/$POD_NAME.embeddedframework/$POD_NAME.framework

# framework存储路径
FRAMEWORK_PATH=./$POD_NAME/Frameworks
FRAMEWORK_DEST_DIR=$FRAMEWORK_PATH/$POD_VERSION

# update framework
rm -rf $FRAMEWORK_PATH
mkdir -p $FRAMEWORK_DEST_DIR
mv $FRAMEWORK_OUTPUT_PATH $FRAMEWORK_DEST_DIR

# lint
pod lib lint ${PODSPEC_NAME} \
	--allow-warnings \
	--sources=$PODSPEC_REPO_URL \
	${USE_LIBRARIES} \
	${VERBOSE_OUTPUT}

if [ $? -ne 0 ]; then
	print_error "pod lib lint [Step 2]"
	rm -rf $OUTPUT_DIR
    exit 1
fi

# commit & push & tag
git add $FRAMEWORK_PATH
git commit -m "update version of framework to $POD_VERSION"
git tag "$POD_VERSION" -m "update tag of framework to $POD_VERSION"
git push
git push --tags

# push to real version to spec-repo
pod repo push $PODSPEC_REPO_NAME $PODSPEC_NAME \
	--sources=$PODSPEC_REPO_URL \
	${USE_LIBRARIES} \
	--allow-warnings \
	${VERBOSE_OUTPUT}

if [ $? -ne 0 ]; then
	print_error "pod repo push [Step 2]"
	rm -rf $OUTPUT_DIR
    exit 1
fi

# clean wording directory
rm -rf $OUTPUT_DIR

exit 0
