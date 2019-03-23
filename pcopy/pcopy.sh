#!/bin/bash

COPY_HOME=`dirname $0`
COPY_HOME=`cd $COPY_HOME; pwd`

source $COPY_HOME/env.sh

START=`date +%s`
echo
echo "`date` Start pcopy job. Copy parallel $COPY_PARALLEL."

eval "$HDFS -mkdir -p $TARGET_BASE_DIR"

# Generate copy source file list
rm -f /tmp/sourcelist
IFS=$'\n'
for LINE in `cat $COPY_HOME/list.txt`
do
    echo "$LINE"
    LS_CMD="hdfs dfs -ls "\"$LINE\"" >> /tmp/sourcelist"
    eval $LS_CMD
done

cat /tmp/sourcelist | awk -F ' ' '{print $8}' > /tmp/tocopy
NUM_COPY=`wc -l /tmp/tocopy | awk '{print $1}'`

LIST_END=`date +%s`
echo "$NUM_COPY files to copy. Generating copy list took $((LIST_END-START)) second(s)."

# Generate copy command list.
echo "Generate copy command list."
rm -f /tmp/copycommands
for FILE in `cat /tmp/tocopy`
do
    DIR=`dirname "$FILE"`
    # extract table dir: file fullpath - base dir
    TABLE_DIR=${DIR:${#SOURCE_BASE_DIR}:256}
    TARGET_DIR="${TARGET_BASE_DIR}${TABLE_DIR}"
    echo "bash $COPY_HOME/copyone.sh $FILE $TARGET_DIR" >> /tmp/copycommands
done


# Execute commands in parallel.
# Better to use GNU parallel, but it may not be available in some environment.
echo "`date` Execute copy command in parallel."
for CMD in `cat /tmp/copycommands`
do
    eval $CMD &
    NPROC=$(($NPROC+1))
    if [ $NPROC -ge $COPY_PARALLEL ]; then
        wait
        NPROC=0
    fi
done
unset IFS

COPY_END=`date +%s`
echo "`date` Done copying files, time: $((COPY_END-LIST_END)) second(s)"

# Check target data size.
echo "Checking target data size."
eval "$HDFS -du -s -h $TARGET_BASE_DIR"

DU_END=`date +%s`

echo
echo "`date` All pcopy tasks done. Total time: $((DU_END-START)) second(s)"
echo "`date` Exit pcopy main program."
