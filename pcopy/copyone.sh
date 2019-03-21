#!/bin/bash

COPY_HOME=`dirname $0`
COPY_HOME=`cd $COPY_HOME; pwd`

source $COPY_HOME/env.sh

FILE=$1
TO_DIR=$2

# create target dir
$S3A -mkdir -p $TO_DIR

# copy file
echo "Copy $FILE to $TO_DIR"
$S3A -cp $FILE $TO_DIR
