# FBBench
====

A collection of FlashBlade benchmark scripts and tools.

# CDP with FB S3

Demo environment
```
Current resources for yj-cld-01:
vCPU: 4
vRAM: 16 GB
Disks:
Size: 100 GB, SCSI ID: 0:0
IPv4 Address: 10.226.228.43
			  192.168.170.96

Current resources for yj-cld-02:
vCPU: 4
vRAM: 16 GB
Disks:
Size: 100 GB, SCSI ID: 0:0
IPv4 Address: 10.226.228.45
			  192.168.170.110

Current resources for yj-cld-03:
vCPU: 4
vRAM: 16 GB
Disks:
Size: 100 GB, SCSI ID: 0:0
IPv4 Address: 10.226.228.49
			  192.168.170.115

Current resources for yj-cld-04:
vCPU: 4
vRAM: 16 GB
Disks:
Size: 100 GB, SCSI ID: 0:0
IPv4 Address: 10.226.228.55
			  192.168.170.116

pureuser/pureuser
```

FB//S
```
192.168.170.101
PSFBSAZRFBEJFJAKADHOEDDNOCFGKCBGIPMODBHECM
6B4F13ECF8612a652+9288/966EB4339b97f3dPBFB
```

Port forwarding to Cloudera Manager:
```
ssh -L 7180:localhost:7180 -N pureuser@yj-cld-01.purestorage.int

```

##  Postgresql setup
Configure Postgresql.
```
cd /etc/postgresql/12/main

vi 

vi pg_hba.conf
--> host    all             all             10.226.228.43/20            md5

vi postgresql.conf
--> listen_addresses = '*'

# restart PG
systemctl restart postgresql.service
```

Create CDP user in PG
```
sudo su postgres
psql

create database hive;
create user hive password 'hive';
grant all privileges on hive to hive;

create database hue;
create user hue password 'hue';
grant all privileges on hue to hue;

create database rman;
create user rman password 'rman';
grant all privileges on rman to rman;

```

## CDP configuration
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
Create a bucket `deephub` in FB S3.

Log into CDP and create directories inside the bucket.
```
hdfs dfs -mkdir -p s3a://deephub/warehouse/nyc_text.db/tlc_yellow_trips_2018/
```

Copy test data to S3.
```
ls -lh 
----
total 197312
197312 -rw-r--r--@ 1 yijiang  staff    89M May 16 15:25 tlc_yellow_trips_2018_1M.csv
```

Example data
```
head -n 3 tlc_yellow_trips_2018_1M.csv

VendorID,tpep_pickup_datetime,tpep_dropoff_datetime,passenger_count,trip_distance,RatecodeID,store_and_fwd_flag,PULocationID,DOLocationID,payment_type,fare_amount,extra,mta_tax,tip_amount,tolls_amount,improvement_surcharge,total_amount
2,05/19/2018 11:51:48 PM,05/20/2018 12:07:31 AM,1,2.01,1,N,48,158,2,11.5,0.5,0.5,0,0,0.3,12.8
1,05/19/2018 11:22:53 PM,05/19/2018 11:35:14 PM,1,1.3,1,N,142,164,2,9,0.5,0.5,0,0,0.3,10.3
```

Copy data to FB S3
```
aws s3 --endpoint-url=http://10.226.224.193 --profile fbs cp tlc_yellow_trips_2018_100k.csv s3://deephub/warehouse/nyc_text.db/tlc_yellow_trips_2018/

# confirm
aws s3 --endpoint-url=http://10.226.224.193 --profile fbs ls  --human-readable s3://deephub/warehouse/nyc_text.db/tlc_yellow_trips_2018/
2024-05-17 16:29:38    8.9 MiB tlc_yellow_trips_2018_100k.csv
```

## Access data in CDP Hive
Query data in FB S3 from CDP Hive using HUE UI.

### Create Hive table
Create a S3 backed external table:
```
CREATE EXTERNAL TABLE IF NOT EXISTS tlc_yellow_trips_2018 (
    vendorid STRING,
    tpep_pickup_datetime STRING,
    tpep_dropoff_datetime STRING,
    passenger_count STRING,
    trip_distance STRING,
    ratecodeid STRING,
    store_and_fwd_flag STRING,
    pulocationid STRING,
    dolocationid STRING,
    payment_type STRING,
    fare_amount STRING,
    extra STRING,
    mta_tax STRING,
    tip_amount STRING,
    tolls_amount STRING,
    improvement_surcharge STRING,
    total_amount STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION 's3a://deephub/warehouse/nyc_text.db/tlc_yellow_trips_2018'
TBLPROPERTIES ('skip.header.line.count' = '1');
```

Run a simple query:
```
SELECT * from tlc_yellow_trips_2018 limit 3;
```

Count number of rows.
```
SELECT count(*) from tlc_yellow_trips_2018;
```

### Insert and query data in Hive

Create a S3 backed external table in Parquet format:
```
CREATE EXTERNAL TABLE IF NOT EXISTS tlc_yellow_trips_2018_parq (
    vendorid STRING,
    tpep_pickup_datetime STRING,
    tpep_dropoff_datetime STRING,
    passenger_count STRING,
    trip_distance STRING,
    ratecodeid STRING,
    store_and_fwd_flag STRING,
    pulocationid STRING,
    dolocationid STRING,
    payment_type STRING,
    fare_amount STRING,
    extra STRING,
    mta_tax STRING,
    tip_amount STRING,
    tolls_amount STRING,
    improvement_surcharge STRING,
    total_amount STRING
)
STORED AS PARQUET
LOCATION 's3a://deephub/warehouse/nyc_parq.db/tlc_yellow_trips_2018'
```

No data in the parquet table.
```
SELECT count(*) from tlc_yellow_trips_2018_parq;
```

Insert data into the parquet table.
```
INSERT INTO tlc_yellow_trips_2018_parq SELECT * FROM tlc_yellow_trips_2018;
```

Confirm data in the parquet table.
```
SELECT count(*) from tlc_yellow_trips_2018_parq;

SELECT * from tlc_yellow_trips_2018_parq limit 3;
```

Check data in FB S3.
```
aws s3 --endpoint-url=http://10.226.224.193 --profile fbs ls --human-readable s3://deephub/warehouse/nyc_parq.db/tlc_yellow_trips_2018/
2024-05-17 16:34:21    3.1 MiB 000000_0
```

## Access data in CDP Impala
Query data in FB S3 from CDP Hive and Impala using HUE UI.

### Create Impala table
Select Impala and create a S3 backed external table:
```
CREATE EXTERNAL TABLE IF NOT EXISTS impala_tlc_yellow_trips_2018 (
    vendorid STRING,
    tpep_pickup_datetime STRING,
    tpep_dropoff_datetime STRING,
    passenger_count STRING,
    trip_distance STRING,
    ratecodeid STRING,
    store_and_fwd_flag STRING,
    pulocationid STRING,
    dolocationid STRING,
    payment_type STRING,
    fare_amount STRING,
    extra STRING,
    mta_tax STRING,
    tip_amount STRING,
    tolls_amount STRING,
    improvement_surcharge STRING,
    total_amount STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION 's3a://deephub/warehouse/nyc_text.db/tlc_yellow_trips_2018'
TBLPROPERTIES ('skip.header.line.count' = '1');
```

Perform metadata update on HUE UI.

Run a simple query:
```
SELECT * from impala_tlc_yellow_trips_2018 limit 3;
```

Count number of rows.
```
SELECT count(*) from impala_tlc_yellow_trips_2018;
```

### Insert and query data in Impala

Create a S3 backed external table in Parquet format in Impala:
```
CREATE EXTERNAL TABLE IF NOT EXISTS impala_tlc_yellow_trips_2018_parq (
    vendorid STRING,
    tpep_pickup_datetime STRING,
    tpep_dropoff_datetime STRING,
    passenger_count STRING,
    trip_distance STRING,
    ratecodeid STRING,
    store_and_fwd_flag STRING,
    pulocationid STRING,
    dolocationid STRING,
    payment_type STRING,
    fare_amount STRING,
    extra STRING,
    mta_tax STRING,
    tip_amount STRING,
    tolls_amount STRING,
    improvement_surcharge STRING,
    total_amount STRING
)
STORED AS PARQUET
LOCATION 's3a://deephub/warehouse/nyc_parq.db/impala_tlc_yellow_trips_2018'
```

No data in the parquet table.
```
SELECT count(*) from impala_tlc_yellow_trips_2018_parq;
```

Insert data into the parquet table.
```
INSERT INTO impala_tlc_yellow_trips_2018_parq SELECT * FROM impala_tlc_yellow_trips_2018;
```

Confirm data in the parquet table.
```
SELECT count(*) from impala_tlc_yellow_trips_2018_parq;

SELECT * from impala_tlc_yellow_trips_2018_parq limit 3;
```

Check data in FB S3.
```
aws s3 --endpoint-url=http://10.226.224.193 --profile fbs ls --human-readable s3://deephub/warehouse/nyc_parq.db/impala_tlc_yellow_trips_2018/
2024-05-17 17:22:06    1.6 MiB 3b4ad6c5397377f3-a30eb79c00000000_949591758_data.0.parq
```

# Troubleshooting
## Host root access issue
Grant no-password sudo to pureuser.
```
sudo visudo

--> add to the last line
pureuser ALL=(ALL:ALL) NOPASSWD:ALL
```

## HUE DB issue
HUE [test DB error](https://stackoverflow.com/questions/41201145/not-able-to-install-hadoop-using-cloudera-manager).
```
curl https://bootstrap.pypa.io/pip/2.7/get-pip.py --output get-pip.py
sudo python2.7 get-pip.py
sudo python2.7 -m pip install psycopg2-binary
ls /usr/local/lib/python2.7/dist-packages/psycopg2
sudo ln -s /usr/local/lib/python2.7/dist-packages/psycopg2 /opt/cloudera/parcels/CDH/lib/hue/build/env/lib/python2.7/site-packages/psycopg2
```