#!/bin/bash

MILLION_ROWS=1000000

# Run random write test
hbase pe randomWrite --nomapred --rows=$MILLION_ROWS 10
