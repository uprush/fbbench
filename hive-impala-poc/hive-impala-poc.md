Cloudera CDP with FB S3 Demo
====
Demonstrate Cloudera CDP and FlashBlade S3 integration.

# Demo environment
Cloudera CDP
* 4 VMs, 4 vCPU, 16GB RAM, 100GB disk each
* 1 CM, 1 master nodes, 2 worker nodes

FlashBlade//S

VM details
```
yj-cld-01 (CM):
IPv4 Address: 10.226.228.43
			  192.168.170.96

yj-cld-02 (master):
IPv4 Address: 10.226.228.45
			  192.168.170.110

yj-cld-03 (worker1):
IPv4 Address: 10.226.228.49
			  192.168.170.115

yj-cld-04 (worker2):
IPv4 Address: 10.226.228.55
			  192.168.170.116

pureuser/pureuser
```

# CDP configuration
4 changes in cluster-wide advanced configuration (core-site.xml)
```
fs.s3a.endpoint=192.168.170.101
fs.s3a.connection.ssl.enabled=false
fs.s3a.access.key=xxx
fs.s3a.secret.key=xxx
```

# CDP with FB S3
Use CDP with FB S3.

## Prepare the data
Example data
```
head -n 3 data_object_storage.csv

nos,customer_category,application_no,channel_code,marketing_program_code,gender_desc,marital_code,flag_contactless,rcc_billing,flag_on_us
1026341249,FFL,SB1100045230,B,B,Female,MAR,NOT CONTACTLESS,SURABAYA,ON US
-274525281,NOR,LF1165386743,0,0,Female,MAR,NOT CONTACTLESS,BALIKPAPAN,ON US
```

Number of rows (including header) in the CSV file:
```
wc -l data_object_storage.csv

100001 data_object_storage.csv
```

### Removing CSV header
It is possible to handler CSV header in Hive and Impala by adding `TBLPROPERTIES ('skip.header.line.count' = '1')` in table definition. However, in this test, we remove the CSV header to avoid confusion. This is because when inserting data into the same table using SQL, even though inserted data do not include header, the first row will still be skipped.

Remove the CSV header and upload to S3.
```
head -n 3 data_object_storage_headless.csv

1026341249,FFL,SB1100045230,B,B,Female,MAR,NOT CONTACTLESS,SURABAYA,ON US
-274525281,NOR,LF1165386743,0,0,Female,MAR,NOT CONTACTLESS,BALIKPAPAN,ON US
2078399363,NOR,LF1140609646,B,B,Male,MAR,NOT CONTACTLESS,BANDUNG,ON US
```

Number of rows (after removing header)
```
wc -l data_object_storage_headless.csv
100000 data_object_storage_headless.csv
```

## Copy data to FB S3
Create a bucket `yifeng` in FB S3.

Log into CDP and create directories inside the S3 bucket using `hdfs` command.
```
ssh pureuser@yj-cld-02.purestorage.int

# clear exsiting data
hdfs dfs -rm -R -f -skipTrash s3a://yifeng/cdp/

# create directories
hdfs dfs -mkdir -p s3a://yifeng/cdp/hive_t1
hdfs dfs -mkdir -p s3a://yifeng/cdp/hive_t1_parq
hdfs dfs -mkdir -p s3a://yifeng/cdp/impala_t1
hdfs dfs -mkdir -p s3a://yifeng/cdp/impala_t1_parq
```


## Access data in CDP Hive
Query data in FB S3 from CDP Hive using HUE UI.

Reference:
* [Apache Hive 3 tables](https://docs.cloudera.com/cdw-runtime/1.5.1/using-hiveql/topics/hive_hive_3_tables.html)

### Prepare
Copy test data to S3.
```
aws s3 --endpoint-url=http://10.226.224.193 --profile fbs cp data_object_storage_headless.csv s3://yifeng/cdp/hive_t1/

# confirm
aws s3 --endpoint-url=http://10.226.224.193 --profile fbs ls  --human-readable s3://yifeng/cdp/hive_t1/
2024-05-20 14:35:54    6.9 MiB data_object_storage_headless.csv
```

Drop exsiting Hive table. Select Hive engine on HUE and run the below:
```SQL
drop table hive_t1;
drop table hive_t1_parq;
```

### Create Hive table
Create a S3 backed Hive external table:
```SQL
CREATE EXTERNAL TABLE IF NOT EXISTS hive_t1 (
    nos STRING,
    customer_category STRING,
    application_no STRING,
    channel_code STRING,
    marketing_program_code STRING,
    gender_desc STRING,
    marital_code STRING,
    flag_contactless STRING,
    rcc_billing STRING,
    flag_on_us STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION 's3a://yifeng/cdp/hive_t1/';
```

Run a simple query:
```SQL
SELECT * from hive_t1 limit 3;
```

Count number of rows.
```SQL
SELECT count(*) from hive_t1;

-- 100,000
```

### Insert and query data in Hive
A simple SQL insert.
```SQL
INSERT INTO hive_t1 VALUES (
    '9999999901',
    'FFL',
    'SB1100045230',
    'B',
    'B',
    'Female',
    'MAR',
    'NOT CONTACTLESS',
    'SURABAYA',
    'ON US'
);
```

Count number of rows after insert.
```sql
SELECT count(*) from hive_t1;

-- 100,001
```

Check files:
```
aws s3 --endpoint-url=http://10.226.224.193 --profile fbs ls  --human-readable s3://yifeng/cdp/hive_t1/

2024-05-20 15:44:13   74 Bytes 000000_0   <-- new file created by INSERT
2024-05-20 15:42:14    6.9 MiB data_object_storage_headless.csv
```

Although Hive supports SQL `INSERT INTO <table> VALUES` for external table, it should be used carefully.
* Slow to insert
* New files are generated everytime SQL INSERT is executed
* Hive does not merge these files

It is recommended to use bulk load to avoid generating too many small files.

### Bulk load in Hive
Bulk load is a common way to ingest large amount of data into a data lake. It is also used for trasform data into efficient format for storage and query. Here we show an example of bulk load 100,000 rows of text data into Parquet format in Hive.

Create a S3 backed external table in **Parquet** format:
```sql
CREATE EXTERNAL TABLE IF NOT EXISTS hive_t1_parq (
    nos STRING,
    customer_category STRING,
    application_no STRING,
    channel_code STRING,
    marketing_program_code STRING,
    gender_desc STRING,
    marital_code STRING,
    flag_contactless STRING,
    rcc_billing STRING,
    flag_on_us STRING
)
STORED AS PARQUET
LOCATION 's3a://yifeng/cdp/hive_t1_parq/';
```

No data in the parquet table.
```sql
SELECT count(*) from hive_t1_parq;
```

Bulk load data from the text table `hive_t1` into the parquet table `hive_t1_parq`.
```sql
INSERT INTO hive_t1_parq SELECT * FROM hive_t1;
```

Confirm data in the parquet table.
```sql
SELECT count(*) from hive_t1_parq;

-- 100,001 (100, 000 originl + 1 inserted above)

SELECT * from hive_t1_parq where nos = '9999999901';
```

Check data in FB S3.
```
aws s3 --endpoint-url=http://10.226.224.193 --profile fbs ls --human-readable s3://yifeng/cdp/hive_t1_parq/
2024-05-20 15:50:18    2.1 MiB 000000_0
```

Note the file size is 2.1 MiB, which is 3x smaller than the CSV file.

## Access data in CDP Impala
Query data in FB S3 from CDP Hive and Impala using HUE UI.

Reference:
* [Overview of Impala Tables](https://impala.apache.org/docs/build/html/topics/impala_tables.html)

### Prepare
Copy test data to S3 for Impala.
```
aws s3 --endpoint-url=http://10.226.224.193 --profile fbs cp data_object_storage_headless.csv s3://yifeng/cdp/impala_t1/

# confirm
aws s3 --endpoint-url=http://10.226.224.193 --profile fbs ls  --human-readable s3://yifeng/cdp/impala_t1/
2024-05-20 14:35:54    6.9 MiB data_object_storage_headless.csv
```

Drop exsiting Impala table. Select Impala engine on HUE and run the below:
```SQL
drop table impala_t1;
drop table impala_t1_parq;
```

### Create Impala table
Select Impala engine on HUE UI and create a S3 backed external table:
```sql
CREATE EXTERNAL TABLE IF NOT EXISTS impala_t1 (
    nos STRING,
    customer_category STRING,
    application_no STRING,
    channel_code STRING,
    marketing_program_code STRING,
    gender_desc STRING,
    marital_code STRING,
    flag_contactless STRING,
    rcc_billing STRING,
    flag_on_us STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION 's3a://yifeng/cdp/impala_t1/';
```

Refresh table on HUE.

Run a simple query:
```sql
SELECT * from impala_t1 limit 3;
```

Count number of rows.
```sql
SELECT count(*) from impala_t1;

-- 100,000
```

### Insert and query data in Impala
A simple SQL insert.
```sql
INSERT INTO impala_t1 VALUES (
    '9999999901',
    'FFL',
    'SB1100045230',
    'B',
    'B',
    'Female',
    'MAR',
    'NOT CONTACTLESS',
    'SURABAYA',
    'ON US'
);
```

Count number of rows after insert.
```sql
SELECT count(*) from impala_t1;

-- 100,001
```

Check files:
```
aws s3 --endpoint-url=http://10.226.224.193 --profile fbs ls  --human-readable s3://yifeng/cdp/impala_t1/

2024-05-20 16:00:03   74 Bytes d948e5a2f76be28a-a5a8a39f00000000_906417100_data.0.txt  <-- new file created by INSERT
2024-05-20 15:57:54    6.9 MiB data_object_storage_headless.csv
```
For the same reason, it is recommended to use bulk load to avoid generating too many small files.

### Bulk load in Impala
Bulk load is a common way to ingest large amount of data into a data lake. It is also used for trasform data into efficient format for storage and query. Here we show an example of bulk load 100,000 rows of text data into Parquet format in Impala.

Create a S3 backed external table in **Parquet** format:
```SQL
CREATE EXTERNAL TABLE IF NOT EXISTS impala_t1_parq (
    nos STRING,
    customer_category STRING,
    application_no STRING,
    channel_code STRING,
    marketing_program_code STRING,
    gender_desc STRING,
    marital_code STRING,
    flag_contactless STRING,
    rcc_billing STRING,
    flag_on_us STRING
)
STORED AS PARQUET
LOCATION 's3a://yifeng/cdp/impala_t1_parq/';
```

No data in the parquet table.
```SQL
SELECT count(*) from impala_t1_parq;
```

Bulk load data from the text table `impala_t1` into the parquet table `impala_t1_parq`.
```SQL
INSERT INTO impala_t1_parq SELECT * FROM impala_t1;
```

Confirm data in the parquet table.
```SQL
SELECT count(*) from impala_t1_parq;
-- 100,001 (100, 000 originl + 1 inserted above)

SELECT * from impala_t1_parq where nos = '9999999901';
```

Check data in FB S3.
```
aws s3 --endpoint-url=http://10.226.224.193 --profile fbs ls --human-readable s3://yifeng/cdp/impala_t1_parq/

2024-05-20 16:14:59    2.9 KiB 54486136c00e95a1-675ee5cf00000000_1761578989_data.0.parq
2024-05-20 16:14:59    1.5 MiB 54486136c00e95a1-675ee5cf00000001_1095080035_data.0.parq
```

Note the file size is 1.5 MiB, which is 4x smaller than the CSV file.


# Additonal Notes
Port forwarding to Cloudera Manager:
```
ssh -L 7180:localhost:7180 -N pureuser@yj-cld-01.purestorage.int

```
