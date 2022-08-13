##!/bin/bash
bucket_name=mytestb1100226

# create_bucket
create_bucket () { aws s3api create-bucket \
	--bucket $bucket_name \
	--region us-east-1 \
	--output text > looog.txt


}

create_bucket

	aws iam attach-user-policy\
	       	--policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess\
	       	--user-name User_num1

aws s3 cp /var/www/html/index.html s3://$bucket_name