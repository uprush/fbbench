#!/bin/bash

HUNDRED_K=100000
ONE_MILLION=1000000
TEN_MILLION=10000000

ROWS=$ONE_MILLION
CLIENTS=10

TEST=$1

if [ $TEST == 'rwrite' ]
then
    # Run random write test
    time hbase pe --nomapred --rows=$ROWS randomWrite $CLIENTS
elif [ $TEST == 'rread' ]
then
    # random read test
    ROWS=$HUNDRED_K
    CLIENTS=20
    time hbase pe --nomapred --rows=$ROWS randomRead $CLIENTS
else
    echo 'unkonwn test'
fi

