#! /bin/sh

set -o xtrace

function new_section {
    set +o xtrace
    echo ""
    echo ""
    echo "========"
    echo $1
    set -o xtrace
}

REGISTRY_URL=http://localhost:4873

if ! command -v verdaccio &> /dev/null
then
    new_section "Installing verdaccio"
    yarn global add verdaccio
fi

VERDACCIO_PID=$(netstat -ano | grep 4873 | awk '{ print $5 }' | head -n1)
if [[ ! "$VERDACCIO_PID" =~ '^[1-9][0-9]+$' ]]
then
    new_section "Setting up verdaccio"
    verdaccio -c ./.ci/verdaccio-config.yaml &
    sleep 1
    VERDACCIO_PID=$(netstat -ano | grep 4873 | awk '{ print $5 }' | head -n1) # $! doesn't work on Windows
fi

new_section "Packaging for NPM"
node scripts/package.js 
new_section "Publishing to local NPM"
cd _esy-package/gnuplot-5.4.3
yarn publish --registry $REGISTRY_URL --new-version 5.4.3000 --use-yarnrc ../../.ci/yarnrc
# See https://github.com/verdaccio/verdaccio/issues/212#issuecomment-308578500
# why yarn instead of npm.

cd ../../esy-test/
export ESY__PREFIX=$HOME/_esy_test/prefix
rm -rf $ESY__PREFIX
mkdir -p $ESY__PREFIX
esy i --npm-registry $REGISTRY_URL
esy b
rm -rf esy.lock
cd ../

case $(uname) in
    CYGWIN*|MINGW*)
	taskkill.exe -pid "$VERDACCIO_PID" -F
	;;
    *)
	kill "$VERDACCIO_PID" 
esac
rm -rf .ci/verdaccio-storage
