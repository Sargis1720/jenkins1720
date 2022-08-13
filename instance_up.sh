#!/bin/bash

vpc_ip=10.0.0.0/16
subnet_1=10.0.1.0/16


#create VPC
vpc=$(aws ec2 create-vpc \
        --cidr-block $vpc_ip \
        --query Vpc.VpcId)
aws ec2 create-tags \
        --resources $vpc \
        --tags Key=Name,Value=My_Vpc

if [[ ! -s $vpc ]]
then
	echo "vpc is createed"
else
	echo "vpc do not created"
        	exit
fi



#Create Subnet1
subnet=$(aws ec2 create-subnet \
        --vpc-id $vpc --cidr-block $subnet_1 \
        --query Subnet.SubnetId)
aws ec2 create-tags \
        --resources $subnet \
        --tags Key=Name,Value=My_subnet

if [[ ! -s $subnet ]]
then
	echo "subnet1 is createed"
else
	echo "subnet1 is do not create"
	delete_for_all_proccess       
		exit
fi



#Create inet_gateway
igw=$(aws ec2 create-internet-gateway \
        --query InternetGateway.InternetGatewayId)
aws ec2 create-tags \
        --resources $igw \
        --tags Key=Name,Value=inet_gateway


if [[ ! -s $igw ]]
then
	echo "igw is createed"
else
	echo "igw do not create"
  delete_for_all_proccess
	exit
fi



#Create gateway_from_vpc
gateway_from_vpc=$(aws ec2 attach-internet-gateway \
        --vpc-id $vpc \
        --internet-gateway-id $igw)

if [[ ! -s $gateway_from_vpc ]]
then
	echo "gateway_from_vpc is createed"
else
	echo "gateway_from_vpc do not create"
	delete_for_all_proccess
		exit

fi


# Create Route Table for vpc
routeTable_for_vpc=$(aws ec2 create-route-table \
        --vpc-id $vpc \
        --query RouteTable.RouteTableId)
aws ec2 create-tags \
        --resources $routeTable_for_vpc \
        --tags Key=Name,Value=r_t_b

if [[ ! -s $routeTable_for_vpc ]]
then
	echo "routeTable_for_vpc is createeid"
else
	echo "routeTable_for_vpc do not create"
	delete_for_all_proccess
		exit
fi



# add route_for_all_trafick
route_for_all_trafick=$(aws ec2 create-route \
        --route-table-id $routeTable_for_vpc \
        --destination-cidr-block 0.0.0.0/0 \
        --gateway-id $igw)

if [[ ! -s $route_for_all_trafick ]]
then
	echo "route_for_all_trafick is created"
else
	echo "route_for_all_trafick do not created"
	delete_for_all_proccess        
	
		exit
fi



describe_route_tables=$(aws ec2 describe-route-tables \
        --route-table-id $routeTable_for_vpc)

if [[ ! -s $describe_route_tables ]]
then
	echo "describe_route_tables is create"
else
	echo "describe_route_tables do not created"
	delete_for_all_proccess
		exit
fi




describe_subnets=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$vpc" \
        --query "Subnets[*].{ID:SubnetId,CIDR:CidrBlock}")

if [[ ! -s $describe_subnets ]]
then
	echo "describe_subnets is create"
else
	echo "describe_subnets is do not created"
  delete_for_all_proccess
		  exit
fi



# associate_route_table
associate_route_table=$(aws ec2 associate-route-table  \
       --subnet-id $subnet \
       --route-table-id $routeTable_for_vpc)

if [[ ! -s $associate_route_table ]]
then
	echo "associate_route_table is ok"
else
	echo "associate_route_table do not add"
  delete_for_all_proccess
       		exit
fi




modify_subnet_attribute=$(aws ec2 modify-subnet-attribute \
        --subnet-id $subnet \
        --map-public-ip-on-launch)

if [[ ! -s $modify_subnet_attribute ]]
then
	echo "modify_subnet_attribute is created"
else
	echo "modify_subnet_attribute do not created"
  delete_for_all_proccess
		exit
fi




# createted key
key_pair=$(aws ec2 create-key-pair \
        --key-name MyKeyPair \
        --query "KeyMaterial" \
        --output text > MyKeyPair.pem)




if [[ ! -s $key_pair ]]
then
	echo "key added"
else
	echo "keydo do not created"
	delete_for_all_proccess        
		exit
fi
chmod 400 ./MyKeyPair.pem


# Create security group
SG=$(aws ec2 create-security-group \
        --group-name SSHAccess \
        --description "Security group for SSH access" \
        --vpc-id $vpc)
        #--tag-specifications 'ResourceType=$SG, Tags=[{Key=Name,Value=Sec_group}]')
aws ec2 create-tags \
    --resources $SG \
    --tags Key=Name,Value=Security_Group

if [[ ! -s $SG ]]
then
	echo "Security group is created"
else
	echo "Security group do not actived"
	delete_for_all_proccess        
		exit
fi




# authorize_security_group
authorize_security_group=$(aws ec2 authorize-security-group-ingress \
        --group-id $SG \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0)

if [[ ! -s $authorize_security_group ]]
then
	echo "authorize_security_group is created"
else
	echo "authorize_security_group do not created"
	delete_for_all_proccess	
		exit
fi

sec=$(aws ec2 authorize-security-group-ingress \
    --group-id $SG \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0)

# Create new instances
run_instance=$(aws ec2 run-instances \
        --image-id ami-052efd3df9dad4825 \
        --count 1 \
        --instance-type t2.micro \
        --key-name MyKeyPair \
        --security-group-ids $SG \
        --subnet-id $subnet \
        --tag-specifications \
	      'ResourceType=instance,Tags=[{Key=Name,Value=instance}]' > log.txt)

if [[ ! -s $run_instance ]]
then
	echo "instance is running"
else
	echo "instace do not created"
	delete_for_all_proccess
		exit
fi


# create instance id
instance_ID=$(grep ami log.txt | cut -n -f 9)


pubip=$(aws ec2 describe-instances \
        --instance-ids $instance_ID \
        --query "Reservations[*].Instances[*].PublicIpAddress" \
        --output text)

sleep 120

connect () {
        # write to known_hosts if there is note
        known_hosts=$(ssh-keyscan $pubip 2> /dev/null)

        if_exist_known_hosts=$(cat ~/.ssh/known_hosts | grep -o "$known_hosts" )

        if [[ ! -n $if_exist_known_hosts ]]
        then
          echo $known_hosts >> ~/.ssh/known_hosts
        fi

# instal nginx
        scp -i "MyKeyPair.pem" ./chack_end_install_ingenix.sh ubuntu@$pubip:/home/ubuntu/chack_end_install_ingenix.sh
        ssh -i "MyKeyPair.pem" ubuntu@$pubip "sudo bash /home/ubuntu/chack_end_install_ingenix.sh"
        scp -i "MyKeyPair.pem" ./script_rate.sh ubuntu@$pubip:/home/ubuntu/script_rate.sh
        ssh -i "MyKeyPair.pem" ubuntu@$pubip "sudo bash script_rate.sh > /dev/null 2>&1 &"
        ssh -i "MyKeyPair.pem" ubuntu@$pubip "sudo rm -rf /var/www/html/index.nginx-debian.html"
        ssh -i "MyKeyPair.pem" ubuntu@$pubip "sudo systemctl reload nginx.service"
}
connect


function delete_for_all_proccess() {

if  [[ -z $vpc ]]
then
        exit
fi

if  [[ -z $subnet1 ]]
then
        aws ec2 delete-vpc --vpc-id $vpc

elif  [[ -z $igw ]]
then
        aws ec2 detach-internet-gateway --internet-gateway-id $igw --vpc-id $vpc
        aws ec2 delete-subnet --subnet-id $subnet1
        aws ec2 delete-vpc --vpc-id $vpc

elif  [[ -z $gateway_from_vpc ]]
then
        aws ec2 detach-internet-gateway --internet-gateway-id $igw --vpc-id $vpc
        aws ec2 delete-internet-gateway --internet-gateway-id $igw
        aws ec2 delete-subnet --subnet-id $subnet1
        aws ec2 delete-vpc --vpc-id $vpc

elif  [[ -z $routeTable_for_vps ]]
then
        aws ec2 detach-internet-gateway --internet-gateway-id $igw --vpc-id $vpc
        aws ec2 delete-internet-gateway --internet-gateway-id $igw
        aws ec2 delete-subnet --subnet-id $subnet1
        aws ec2 delete-vpc --vpc-id $vpc

elif  [[ -z $route_for_all_trafick ]]
then
        aws ec2 detach-internet-gateway --internet-gateway-id $igw --vpc-id $vpc
        aws ec2 delete-route-table --route-table-id $routeTable_for_vpc
        aws ec2 delete-internet-gateway --internet-gateway-id $igw
        aws ec2 delete-subnet --subnet-id $subnet1
        aws ec2 delete-vpc --vpc-id $vpc

elif  [[ -z $SG ]]
then
        aws ec2 detach-internet-gateway --internet-gateway-id $igw --vpc-id $vpc
        aws ec2 delete-subnet --subnet-id $subnet1
        aws ec2 delete-internet-gateway --internet-gateway-id $igw
        aws ec2 delete-route-table --route-table-id $routeTable_for_vpc
        aws ec2 delete-vpc --vpc-id $vpc

elif  [[ -z $run_instance ]]
then
        aws ec2 detach-internet-gateway --internet-gateway-id $igw --vpc-id $vpc
        aws ec2 delete-subnet --subnet-id $subnet1
        aws ec2 delete-vpc --vpc-id $vpc
        aws ec2 delete-internet-gateway --internet-gateway-id $igw
        aws ec2 delete-route-table --route-table-id $routeTable_for_vpc
        aws ec2 delete-security-group --group-id $SG
fi

}

delete_for_all_proccess