#!/bin/bash

FROM_DIR=/user/pureuser/teragen
TO_DIR=s3a://deephub/user/pureuser
MAPS=4

hadoop distcp -m $MAPS $FROM_DIR $TO_DIR
