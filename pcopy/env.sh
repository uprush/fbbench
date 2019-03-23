#!/bin/bash

SOURCE_BASE_DIR=/user/pureuser/pcopy/labtest.db
TARGET_BASE_DIR=s3a://deephub/user/pureuser/pcopy/labtest
COPY_PARALLEL=2

S3_ACCESS_KEY=""
S3_SECRET_KEY=""
S3_END_POINT=""

HDFS="hdfs dfs -Dfs.s3a.access.key=\"$S3_ACCESS_KEY\" -Dfs.s3a.secret.key=\"$S3_SECRET_KEY\" -Dfs.s3a.endpoint=\"$S3_END_POINT\" -Dfs.s3a.connection.ssl.enabled=\"false\""
