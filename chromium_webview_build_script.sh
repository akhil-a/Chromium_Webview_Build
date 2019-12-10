#!/bin/bash
#Setting up base directory
SCRIPT_DIR=$(pwd)
ROOT_DIR=${SCRIPT_DIR}/webview

CHROMIUM_DIR=${ROOT_DIR}/chromium


if [ -z $WEBVIEW_VERSION ]; then
	echo "Web View Version Empty. Please provide valid tag."
	exit -1
fi

setup_environment () {

#Chromium and Chromium OS use a package of scripts called depot_tools to manage checkouts and code reviews.
#The depot_tools package includes gclient, gcl, git-cl,repo, and others.

if [ ! -d ${ROOT_DIR}/depot_tools ]; then
	echo "Cloning Depot Tools."
	git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
fi

export PATH=$PATH:${ROOT_DIR}/depot_tools

}

fetch_chromium () {

echo "Fetching Chromium."

if [ ! -d $CHROMIUM_DIR ]; then
  rm -rf $CHROMIUM_DIR  
fi
mkdir $CHROMIUM_DIR 

cd $CHROMIUM_DIR
fetch --nohooks android

}

fetch_release_tags () {

echo "Fetching release tags."

#Ensure all release tags in the checkout

cd $CHROMIUM_DIR/src

git fetch --tags

git checkout -b $WEBVIEW_BRANCH $WEBVIEW_VERSION 

gclient sync --with_branch_heads --with_tags

#Ensure whether correct version is going to buld
cat chrome/VERSION
}

build_chromium () {

echo "Building Chromium."

cd $CHROMIUM_DIR/src

git diff

echo "Version : $(cat chrome/VERSION)"

#New Android dependencies
echo $BUILD_AGENT_PASS | sudo build/install-build-deps-android.sh

#Once you've run install-build-deps at least once, you can now run the Chromium-specifichooks, which will download additional binaries and other things you might need:

gclient runhooks

#Setting up the Build
gn gen --args='target_os="android" target_cpu="arm64" is_debug=false is_official_build=true
is_chrome_branded=false use_official_google_api_keys=false
enable_resource_whitelist_generation=true ffmpeg_branding="Chrome" proprietary_codecs=true
enable_remoting=true' out/webview_arm64

ninja -C out/webview_arm64 system_webview_apk

webview_apk_out=$CHROMIUM_DIR/src/out/webview_arm64/apks/SystemWebView.apk

echo "Output in Build Machine : $webview_apk_out"

echo "Output in Jenkins : http://192.168.3.230:8080/job/RSE_Build_Chromium_Webview/${BUILD_NUMBER}/artifact/webview/chromium/src/out/webview_arm64/apks/"

}


if [ "$BUILD_OPTION" == "Full Build" ]; then
	
    if [ ! -d $ROOT_DIR ]; then
 	 	rm -rf $ROOT_DIR  
	fi
    
	mkdir $ROOT_DIR
	cd $ROOT_DIR

	setup_environment
	fetch_chromium
	fetch_release_tags
	build_chromium

elif [ "$BUILD_OPTION" == "Incremental Build" ]; then
	if [ ! -d $ROOT_DIR ]; then
 	 	echo "Root Directory missing. Please do a full build."
        exit 1
	fi
    
	cd $ROOT_DIR
    setup_environment
	fetch_release_tags
	build_chromium

elif [ "$BUILD_OPTION" == "Fetch Source Only" ]; then
	if [ ! -d $ROOT_DIR ]; then
 	 	echo "Root Directory missing. Please do a full build."
        exit 1
	fi
    
	cd $ROOT_DIR
    setup_environment
	fetch_release_tags

elif [ "$BUILD_OPTION" == "Build Only" ]; then
	if [ ! -d $ROOT_DIR ]; then
 	 	echo "Root Directory missing. Please do a full build."
        exit 1
	fi
    
	cd $ROOT_DIR
    setup_environment
    build_chromium
    
elif [ "$BUILD_OPTION" == "Publish Artifacts" ]; then

 	 	echo "Publish Artifact"
        echo "Output in Jenkins : http://192.168.3.230:8080/job/RSE_Build_Chromium_Webview/${BUILD_NUMBER}/artifact/webview/chromium/src/out/webview_arm64/apks/"
  
fi
