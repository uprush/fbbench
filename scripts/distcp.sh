#!/bin/bash

#FROM_DIR=s3a://deephub/user/pureuser/teragen
#TO_DIR=/user/pureuser/teragen/output
FROM_DIR=/user/pureuser/teragen/output/*
TO_DIR=s3a://deephub/user/pureuser/teragen
LOG_DIR=/user/pureuser/distcplogs
MAPS=40

hdfs dfs -rm -r -skipTrash $TO_DIR

#time hadoop distcp -m $MAPS -v -log $LOG_DIR $FROM_DIR $TO_DIR
time hadoop distcp -direct -m $MAPS -v -log $LOG_DIR $FROM_DIR $TO_DIR

