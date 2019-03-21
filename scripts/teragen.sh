#!/bin/bash

GEN_HOME=s3a://deephub/user/pureuser/teragen
GEN_DIR=s3a://deephub/user/pureuser/teragen/output
#GEN_HOME=/user/pureuser/teragen
#GEN_DIR=/user/pureuser/teragen/output

hdfs dfs -mkdir -p $GEN_HOME
hdfs dfs -rm -r -skipTrash $GEN_DIR

ONE_GB=10000000
TEN_GB=100000000
HUNDRED_GB=1000000000
ONE_TB=10000000000
MAPS=40

TO_GEN=$TEN_GB

echo
echo "`date` Generating $TO_GEN data on FlashBlade..."

time yarn jar \
    /usr/hdp/current/hadoop-mapreduce-client/hadoop-mapreduce-examples.jar \
    teragen \
    -Dmapreduce.job.maps=$MAPS \
    -Dmapreduce.job.reduces=0 \
    $TO_GEN $GEN_DIR

echo
echo "`date` $TO_GEN data generate."

