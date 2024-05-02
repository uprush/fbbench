#!/bin/bash

HUNDRED_K=100000
FIVE_HUNDRED_K=500000
ONE_MILLION=1000000
TEN_MILLION=10000000

CLIENTS=2

TEST=$1

if [ $TEST == 'rwrite' ]
then
    echo "Disabling TestTable."
    echo "disable 'TestTable'" | hbase shell -n

    echo "Deleting TestTable."
    echo "drop 'TestTable'" | hbase shell -n
    echo 

    echo "Run random write test"
    ROWS=$ONE_MILLION
    time hbase pe --presplit=8 --nomapred --rows=$ROWS randomWrite $CLIENTS
elif [ $TEST == 'rread' ]
then
    echo "Run random read test"
    ROWS=$HUNDRED_K
    time hbase pe --nomapred --rows=$ROWS randomRead $CLIENTS
else
    echo 'unkonwn test'
fi
