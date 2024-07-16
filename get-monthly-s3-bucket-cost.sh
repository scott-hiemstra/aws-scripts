#!/bin/env bash

# This script gets the sizes of all S3 buckets in GB using cloudwatch metrics
# Cloudwatch metrics is being used to get the size of the bucket because using
#   s3api list-objects-v2 is not efficient for large buckets
# Monthly bucket cost is then calculated by multiplying the size by the default 
#   storage class cost

buckets=$(aws s3api list-buckets --query 'Buckets[*].Name' --output text)
for bucket in $buckets; do
    region=$(aws s3api get-bucket-location --bucket $bucket --query 'LocationConstraint' --output text)
    if [ "$region" == "None" ]; then
        region="us-east-1"
    fi
    size=$(aws cloudwatch get-metric-statistics --region $region --namespace AWS/S3 --metric-name BucketSizeBytes --dimensions Name=BucketName,Value=$bucket Name=StorageType,Value=StandardStorage --start-time $(date -u -d "-1 day" +%Y-%m-%dT00:00:00Z) --end-time $(date -u +%Y-%m-%dT00:00:00Z) --period 86400 --statistics Average --unit Bytes --output text --query 'Datapoints[0].Average')
    size=$(echo "scale=2; $size / 1024 / 1024 / 1024" | bc)
    cost=$(echo "scale=2; $size * 0.023" | bc | awk '{printf "%.2f\n", $0}')
    echo "$bucket: $size GB | \$$cost USD/Month"
done
