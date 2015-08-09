#!/usr/bin/env bash
set -euo pipefail

source ./settings

repo=$SAGE_REPO
before=$SAGE_BEFORE_COMMIT
after=$SAGE_AFTER_COMMIT
clean=false
skipNPM=false
# get command
if [ $# -ne 0 ]
then
  case "$1" in
  clean)
    clean=true
    ;;
  rerun)
    skipNPM=true
    ;;
  esac
fi


echo "*****************"
echo "Debug Information"
echo "*****************"

printf "%s\t%s\n" "node version" $(node -v)
printf "%s\t%s\n" "npm version" $(npm -v)

echo

echo "************"
echo "Running Test"
echo "************"

if [ ! -d .tmp ]
then
  echo "creating tmp dir"
  mkdir -p .tmp
else
  if $clean
  then
    echo "cleaning tmp dir"
    rm -rf .tmp/*
  fi
fi

for dir in before after
do
(
  cd ./.tmp
  if [ ! -d $dir ]
  then
    echo "creating directory $dir"
    mkdir $dir
  fi


  if [ ! -d $dir/.git ]
  then
    echo "cloning sage"
    git clone $repo $dir
  else
    echo "updating sage"
    (cd $dir && git fetch --all)
  fi

  cd $dir

  git checkout ${!dir} -q
  echo "$dir is now at $(git rev-parse --verify HEAD)"
  if [ -d node_modules ]
  then
    if ! $skipNPM
    then
      echo "updating npm modules. This could take a while....."
      npm update &>/dev/null
    fi
  else
    echo "installing npm modules. This could take a while....."
    npm install &>/dev/null
  fi
  npm list --depth=0
)
done


