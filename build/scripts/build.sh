#!/bin/sh
#
# NOTE:
# This script assumes that your terminal supports ANSI Escape Codes and colors.
# It should not fail if your terminal does not support it--the output will just
# look a bit garbled.
#
GREEN='\033[32m'
RED='\033[31m'
NOCOLOR='\033[0m'
TIMESTAMP=$(date '+%Y-%m-%d@%H:%M:%S')
VERSION="0.3.0"

if [ "$(uname)" == "Darwin" ]; then
	ECHOFLAGS=""
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
	ECHOFLAGS="-e"
fi

# Unfortunately, because this is running in a shell script, brace expansion
# might not work, so I can't create all the necessary directories "the cool
# way." See this StackOverflow question that addresses my problem:
# https://stackoverflow.com/questions/40164660/bash-brace-expansion-not-working-on-dockerfile-run-command
mkdir -p ./documentation
mkdir -p ./documentation/html
mkdir -p ./documentation/links
mkdir -p ./build
mkdir -p ./build/assemblies
mkdir -p ./build/executables
mkdir -p ./build/interfaces
mkdir -p ./build/libraries
mkdir -p ./build/logs
mkdir -p ./build/maps
mkdir -p ./build/objects
mkdir -p ./build/scripts

echo $ECHOFLAGS "Building the CSPRNG Library (static)... \c"
if dmd \
 ./source/macros.ddoc \
 ./source/csprng/*.d \
 -Hd./build/interfaces \
 -op \
 -of./build/libraries/csprng-${VERSION}.a \
 -Xf./documentation/csprng-${VERSION}.json \
 -lib \
 -inline \
 -release \
 -O \
 -map \
 -v >> ./build/logs/${TIMESTAMP}.log 2>&1; then
    echo $ECHOFLAGS "${GREEN}Done.${NOCOLOR}"
else
    echo $ECHOFLAGS "${RED}Failed. See ./build/logs.${NOCOLOR}"
fi

echo $ECHOFLAGS "Building the CSPRNG Library (shared / dynamic)... \c"
if dmd \
 ./source/csprng/*.d \
 -of./build/libraries/csprng-${VERSION}.so \
 -shared \
 -fPIC \
 -inline \
 -release \
 -O \
 -v >> ./build/logs/${TIMESTAMP}.log 2>&1; then
    echo $ECHOFLAGS "${GREEN}Done.${NOCOLOR}"
else
    echo $ECHOFLAGS "${RED}Failed. See ./build/logs.${NOCOLOR}"
fi

echo $ECHOFLAGS "Building the CSPRNG Command-Line Tool, get-cryptobytes... \c"
if dmd \
 ./source/tools/get_cryptobytes.d \
 -I./build/interfaces/source \
 ./build/libraries/csprng-${VERSION}.a \
 -of./build/executables/get-cryptobytes \
 -inline \
 -release \
 -O \
 -v >> ./build/logs/${TIMESTAMP}.log 2>&1; then
    echo $ECHOFLAGS "${GREEN}Done.${NOCOLOR}"
else
    echo $ECHOFLAGS "${RED}Failed. See ./build/logs.${NOCOLOR}"
fi