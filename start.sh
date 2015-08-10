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

# platform detection
platform='unknown'
unamestr=$(uname)
if [[ "$unamestr" == 'Linux' ]]
then
   platform='linux'
elif [[ "$unamestr" == 'FreeBSD' ]]
then
   platform='freebsd'
fi

if [[ $platform == 'freebsd' ]]
then
  if hash gtime 2>/dev/null
  then
    alias time='gtime'
  else
    echo "ERROR: You need gtime installed. brew install gnu-time"
    exit 1
  fi
fi


if ! hash gtime 2>/dev/null
then
  echo "ERROR: You need csv2md installed. npm install -g csv2md"
  exit 1
fi

echo "# Debug Information"

echo '```'
printf "%s\t%s\n" "node version" $(node -v)
printf "%s\t%s\n" "npm version" $(npm -v)
echo '```'

echo

echo "# Running Setup"

if [ ! -d .tmp ]
then
  echo "* creating tmp dir"
  mkdir -p .tmp
else
  if $clean
  then
    echo "* cleaning tmp dir"
    rm -rf .tmp/*
  fi
fi

for dir in before after
do
(
  cd ./.tmp
  if [ ! -d $dir ]
  then
    echo "* creating directory $dir"
    mkdir $dir
  fi


  if [ ! -d $dir/.git ]
  then
    echo "* cloning sage"
    echo '```'
    git clone $repo $dir
    echo '```'
  else
    echo "* updating sage"
    echo '```'
    (cd $dir && git reset --hard && git fetch --all)
    echo '```'
  fi

  cd $dir

  git checkout ${!dir} -q
  echo "* $dir is now at $(git rev-parse --verify HEAD)"
  if [ -d bower_components ]
  then
    if ! $skipNPM
    then
      echo "* updating bower."
      bower -q update
    fi
  else
    echo "* installing bower modules"
    bower -q install
  fi
  if [ -d node_modules ]
  then
    if ! $skipNPM
    then
      echo "* updating npm modules. This could take a while....."
      npm update &>/dev/null
    fi
  else
    echo "* installing npm modules. This could take a while....."
    npm install &>/dev/null
  fi
  echo '```'
  npm list --depth=0
  echo '```'
)
done

echo

kitchSinkBower="angular angular-ui-router lodash d3 animate.css moment"

echo "
# Running Comparisons

These are the variants of the trials to be run:

* barebones: this is what comes with the repo by default.
* angular.js: install angular via bower.
* kitchen sink: install a whole bunch of stuff. $kitchSinkBower

"

function runGulp {
  # usage
  # runGulp stage variation outputFile
  stage=$1
  variation=$2
  outputFile=$3
  header="trial, variation, time (seconds), commit, command"

  if [ ! -f "$outputFile" ]
  then
    echo "$header" > $outputFile
  fi

  for i in {1..5}
  do
    gtime -f "$stage, $variation, %e, ${!1}, %C" -o $3 --append gulp >/dev/null 2>/dev/null
  done
}

resultsFile=$(pwd)/.tmp/results.csv
[ -f "$resultsFile" ] && rm $resultsFile

for dir in before after
do
  echo
  echo "## Profiling $dir"

  (
    cd ./.tmp/$dir
    echo "* Running variant “barebones”"
    runGulp $dir 'barebones' $resultsFile
    echo "* Running variant “angular.js”"
    bower -s install angular --save
    runGulp $dir 'angular.js' $resultsFile
    bower -s uninstall angular --save
    echo "* Running variant “kitchen sink”"
    bower -s install $kitchSinkBower --save
    runGulp $dir 'kitchen sink' $resultsFile
    bower -s uninstall $kitchSinkBower --save
  )

done

echo
echo
cat $resultsFile | csv2md
