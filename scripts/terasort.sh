#!/bin/bash

SORT_HOME=s3a://deephub/user/pureuser/terasort
SORT_DIR=s3a://deephub/user/pureuser/terasort/output

hdfs dfs -mkdir -p $SORT_HOME
hdfs dfs -rm -r -skipTrash $SORT_DIR

GEN_DIR=s3a://deephub/user/pureuser/teragen/output
REDUCES=4

echo
echo "`date` Start 1TB data sort..."

time yarn jar \
    /usr/hdp/current/hadoop-mapreduce-client/hadoop-mapreduce-examples.jar \
    terasort \
    -Dmapreduce.job.reduces=$REDUCES \
    $GEN_DIR \
    $SORT_DIR

echo
echo "`date` Done terasort."
