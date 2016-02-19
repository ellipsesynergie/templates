#!/bin/bash

#
git update-server-info

#---------------
#CONFIGURATIONS

#Base path
BASEPATH="/var/www/"

#The application name
APP="yoursite.com"

#App path
APPPATH=$BASEPATH$APP

#The git repository
REPOSITORY="git@localhost:yoursite.com"

#The Newrelic API key
NEWRELIC=""

#The current environment
ENVIRONMENT=demo

#Deployment hooks
BUILD_HOOK=""
POST_DEPLOYMENT_HOOK=""
#---------------

#Start timer
START_TIMER=`date +%s`

#Current timestamp
TIMESTAMP=$(date +%Y%m%d-%Hh%M-%s)

#By default, no errors
ERRCNT=0

#Generate build folder name
BUILDPATH="$APPPATH/build-$TIMESTAMP"

#Get the current release
CURRENT_RELEASE=`readlink $APPPATH/current`

#If the APPPATH directory exist
if [ ! -d "$APPPATH" ]; then
  echo " ! The application directory [$APPPATH] doesn't exist"
  exit 1
fi

#If the BUILDPATH directory exist
if [ -d "$BUILDPATH" ]; then
  echo " ! The build directory [$BUILDPATH] already exist"
  exit 2
fi

#Geting the branch name to deploy
BRANCHNAME=$(git rev-parse --symbolic --abbrev-ref $1)

#Starting the deploy process
echo
echo "***** Starting deployment for [$APP] on branch [$BRANCHNAME]*****"
echo

#Clone the repository into build folder
git clone --depth=1 --branch=$BRANCHNAME $REPOSITORY $BUILDPATH

#Go to the build folder
echo " + Go to build folder [$BUILDPATH]"
cd $BUILDPATH

#VERY important because when the post-update hook is executed, executing git command to another repository will fail
unset GIT_DIR

#Get the version
VERSION=`git rev-list --max-count=1 HEAD`

if [ ! $VERSION ]; then
  echo " ! Problem getting the version"
  rm -rf $BUILDPATH
  exit 3;
fi

#Execute the build hook
if [ $BUILD_HOOK ]; then
  echo " + Executing build HOOK"
  $BUILD_HOOK
fi

#Return to app folder
cd $APPPATH

#Move the build folder to NEW_RELEASE
NEW_RELEASE="release-$VERSION"

#Preparing the new release
echo " + Preparing new release [$VERSION]"

#If the is not the same then the new release
if [ "$CURRENT_RELEASE" != "$APPPATH/$NEW_RELEASE" ] ; then

  #Move the build folder to release folder
  mv $BUILDPATH $APPPATH/$NEW_RELEASE

  #This step has to be done at the end of the deploy process, ie when everything is ready
  echo " + Promoting $NEW_RELEASE into $ENVIRONMENT"
  rm -f $APPPATH/current ; ln -s $APPPATH/$NEW_RELEASE $APPPATH/current

  #Remove the old release
  echo " + Removing old release [$CURRENT_RELEASE]"
  rm -rf $CURRENT_RELEASE
else
  echo "  + This version is already into $ENVIRONMENT"

  #Remove the build folder
  echo " + Remove the build folder [$BUILDPATH]"
  rm -rf $BUILDPATH
fi

#Execute the post deployment hook
if [ $POST_DEPLOYMENT_HOOK ]; then
  echo " + Executing post deployment HOOK"
  $POST_DEPLOYMENT_HOOK
fi

#Log the deployment to Newrelic
curl -s -H "x-api-key:$NEWRELIC" -d "deployment[app_name]=$APP" -d "deployment[revision]=$VERSION" https://rpm.newrelic.com/deployments.xml -o /dev/null

#Restart service
#sudo /etc/init.d/apache2 reload
#sudo /etc/init.d/nginx reload

#Duration
DEPLOYMENT_DURATION=$((`date +%s` - $START_TIMER))