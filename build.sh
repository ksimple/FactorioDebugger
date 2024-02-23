#!/bin/bash

SCRIPT_PATH=$(realpath $0)
SCRIPT_DIR=$(dirname ${SCRIPT_PATH})

VERSION=$1

if [[ "${VERSION}" == "" ]]; then
    VERSION=99.99.99
fi
MOD_NAME=debugger

echo VERSION: ${VERSION}

rm -rf ${SCRIPT_DIR}/build/${MOD_NAME}_${VERSION}
rm -rf ${SCRIPT_DIR}/release/${MOD_NAME}_${VERSION}.zip
mkdir -p ${SCRIPT_DIR}/build/${MOD_NAME}_${VERSION}
mkdir -p ${SCRIPT_DIR}/release
cp -r src/* ${SCRIPT_DIR}/build/${MOD_NAME}_${VERSION}
sed -i -e s/\${VERSION}/${VERSION}/ ${SCRIPT_DIR}/build/${MOD_NAME}_${VERSION}/info.json
cd ${SCRIPT_DIR}/build
zip -r ${SCRIPT_DIR}/release/${MOD_NAME}_${VERSION}.zip ${MOD_NAME}_${VERSION}
