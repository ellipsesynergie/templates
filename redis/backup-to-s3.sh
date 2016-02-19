#!/bin/sh

# Force database saving, must be in another cron propably
redis-cli bgsave

# set dates
NOWDATE=`date +%Y-%m-%d-%H:%M`

# set backup directory variables
SRCDIR='/tmp/s3backups'
DESTDIR=`date +%Y-%m`
BUCKET='bucket-name'

#### END CONFIGURATION ####

# make the temp directory if it doesn't exist
mkdir -p $SRCDIR

# make a compressed copy of the redis dump

cp /var/lib/redis/redis.rdb $SRCDIR/$NOWDATE-redis-dump.rdb
gzip $SRCDIR/$NOWDATE-redis-dump.rdb

# send the file off to s3
aws s3 cp $SRCDIR/$NOWDATE-redis-dump.rdb.gz s3://$BUCKET/$DESTDIR/

# remove all files in our source directory
rm -f $SRCDIR/*