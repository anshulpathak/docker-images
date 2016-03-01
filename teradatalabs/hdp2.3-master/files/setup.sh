#!/bin/bash

set -ex

# 1 format namenode
chown hdfs:hdfs /var/lib/hadoop-hdfs/cache/
su -c "echo 'N' | hdfs namenode -format" hdfs

# 2 start hdfs
su -c "hdfs namenode  2>&1 > /var/log/hadoop/hdfs/hadoop-hdfs-namenode.log" hdfs&

# 3 wait for process starting
sleep 10

# 4 exec hdp hdfs init script
# Failure on error is disabled and then enabled here because the
# init-hdfs.sh script attempts to upload a jar to HDFS and that fails
# because there is no Hadoop cluster up.
set +e
/usr/hdp/2.3.*/hadoop/libexec/init-hdfs.sh
set -e

# 4.1 Create an hdfs home directory for the yarn user. For some reason, init-hdfs doesn't do so.
su -s /bin/bash hdfs -c '/usr/bin/hadoop fs -mkdir /user/yarn && /usr/bin/hadoop fs -chown yarn:yarn /user/yarn'

# 5 init hive directories
su -s /bin/bash hdfs -c '/usr/bin/hadoop fs -mkdir /user/hive/warehouse'
su -s /bin/bash hdfs -c '/usr/bin/hadoop fs -chmod g+w /user/hive/warehouse'
su -s /bin/bash hdfs -c '/usr/bin/hadoop fs -chown hive /user/hive/warehouse'

# 6 stop hdfs
killall java

# 7 setup metastore
mysql_install_db

/usr/bin/mysqld_safe &
sleep 10s

cp /usr/hdp/2.3.*/hive/scripts/metastore/upgrade/mysql/hive-schema-0.14.0.mysql.sql /tmp/hive-schema-0.14.0.mysql.sql
echo "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION; FLUSH PRIVILEGES;" | mysql
echo "CREATE DATABASE metastore; USE metastore; SOURCE /usr/hdp/2.3.0.0-2557/hive/scripts/metastore/upgrade/mysql/hive-schema-0.14.0.mysql.sql;" | mysql
/usr/bin/mysqladmin -u root password 'root'
rm -f /tmp/hive-schema-0.14.0.mysql.sql

killall mysqld
sleep 10s
mkdir /var/log/mysql/
chown mysql:mysql /var/log/mysql/

exit 0
