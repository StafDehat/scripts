#!/bin/bash

# Title:   cloud-files-bulk-objects.sh
# Version: 1.1
# Author:  Dave Kludt
#          Additional regions (beyond DFW & ORD) added by Andrew Howard
# Purpose: Automate the upload/download/deletion of multiple files from
#          a Cloud Files container.
# Danger:  This script *may* download many files to local directories,
#          upload files to Cloud Files containers, and/or delete files
#          from Cloud Files containers.


getToken () {
    auth_response=`/usr/bin/curl -s -XPOST -H "Content-Type: application/json" -d '{"auth":{"RAX-KSKEY:apiKeyCredentials":{"username":"'$username'","apiKey":"'$key'"}}}' https://identity.api.rackspacecloud.com/v2.0/tokens`;
    token=`echo $auth_response | grep -m1 -oP '(?<="token":{"id":")[^"]*'`
    if [ "$access_point" == "yes" ]; then
    	temp_urls=`echo $auth_response | tr '{}' '\n' | while read LINE; do if [[ \`echo $LINE | grep -c clouddrive\` -gt 0  && \`echo $LINE | grep -c storage\` -gt 0 ]]; then echo "$LINE"; fi done | sed 's/":/",/g' | sed 's/"//g' | awk -F , '{ print $8 }'`
    else
    	temp_urls=`echo $auth_response | tr '{}' '\n' | while read LINE; do if [[ \`echo $LINE | grep -c clouddrive\` -gt 0  && \`echo $LINE | grep -c storage\` -gt 0 ]]; then echo "$LINE"; fi done | sed 's/":/",/g' | sed 's/"//g' | awk -F , '{ print $6 }'`
    fi   
    for x in `echo "$temp_urls"`
    do
    	if [ `echo $x | grep -c 'dfw1'` -gt 0 ]; then
    		dfw_url=$x
	elif [ `echo $x | grep -c 'ord1'` -gt 0 ]; then
    		ord_url=$x
	elif [ `echo $x | grep -c 'syd2'` -gt 0 ]; then
    		syd_url=$x
	elif [ `echo $x | grep -c 'iad3'` -gt 0 ]; then
    		iad_url=$x
	elif [ `echo $x | grep -c 'hkg1'` -gt 0 ]; then
    		hkg_url=$x
    	fi
    done
}

upload_files_into_container () {
	san_file_path=`echo "$file_path" | sed 's/\//\\\\\//g'`
	sani_files=`find $file_path | sed "s/"$san_file_path"//"`
	count=0
	for file in ${sani_files[@]}; do
		upload_file_name=`echo $file | sed 's/^\///'`		
		echo -e "Uploading $file_path/$upload_file_name..."
		curl -XPUT -T $file_path/$upload_file_name -H "X-Auth-Token: $token" "$dc_url/$cloud_container/$upload_file_name"
		(( count+=1 ))
	done
	echo -e "\nUploaded $count files to Container $cloud_container\n"
}

create_container () {
	echo -e "\nChecking/Creating Container..."
	create_response=`curl -s -XPUT -D - -H "X-Auth-Token: $token" "$dc_url/$cloud_container"`
	if [ `echo $create_response | grep -c "accepted"` -gt 0 ]; then
		echo -e "Container already exists\n"
	elif [ `echo $create_response | grep -c "Created"` -gt 0 ];	then
		echo -e "Container created\n"
	else
		echo "There was an error, exiting..."
		exit
	fi
}

check_download_path () {
	if [ -d "$file_path" ];	then
		echo "Directory Exists..."
	else
		echo "Creating directory..."
		mkdir -p $file_path
	fi
}

download_files_from_container () {
	echo "Download files from specified container"
	file_list=`curl -s -XGET -H "X-Auth-Token: $token" "$dc_url/$cloud_container"`
	count=0
	echo "Creating directory structure..."
	for file in ${file_list[@]}; do
		temp_file=(${file//\// })
		if [ ${#temp_file[@]} -gt 1 ]; then
			unset temp_file[${#temp_file[@]}-1]
			for temp in ${temp_file[@]}; do
				mkdir -p "$file_path/$temp"
			done
		fi
	done
	
	echo "Downloading files..."
	for file in ${file_list[@]}; do
		if [ -d "$file_path/$file" ]; then
			echo "Skipping directory file..."
		else
			echo -e "Downloading file $file..."
			response=`curl -s XGET -H "X-Auth-Token : $token" "$dc_url/$container/$file" > "$file_path/$file"`
			if [ -n "$response" ]; then
				echo "Error - $response"
			fi
			(( count+=1 ))
		fi
	done
	echo -e "\nDownloaded $count files from Container $cloud_container"
}

delete_files_from_container () {
	echo "Delete files from specified container"
	echo -e "Getting list of all objects in Container...\n"
	file_list=`curl -s -XGET -H "X-Auth-Token: $token" "$dc_url/$cloud_container"`
	count=0
	for file in ${file_list[@]}; do
		echo "Deleting file $file..."
		delete_response=`curl -s -XDELETE -H "X-Auth-Token: $token" "$dc_url/$cloud_container/$file"`
		(( count+=1 ))
	done
	echo -e "\nDeleted $count files from Container $cloud_container\n"
}

get_cloud_container () {
	echo -e "\nEnter Cloud Files Container"
	read cloud_container
	if [ -z $cloud_container ];	then
		echo -e "\nEmpty choice is not valid"
		get_cloud_container
	fi
}

get_file_path () {
	direction=$1
	echo -e "\nEnter in path"
	read file_path
	if [ -z $file_path ]; then
		echo -e "\nFile path is empty"
	fi
	file_path=`echo $file_path | sed "s/\/$//g"`
}

get_datacenter () {
	echo -e "\nChoose Datacenter
1) DFW
2) ORD
3) IAD
4) HKG
5) SYD"
	read cloud_datacenter
	case "$cloud_datacenter" in
		1) dc_url=$dfw_url ;;
		2) dc_url=$ord_url ;;
                3) dc_url=$iad_url ;;
                3) dc_url=$hkg_url ;;
                3) dc_url=$syd_url ;;
		*) echo -e "Setting DFW as the DC"
		   dc_url=$dfw_url ;;
	esac
}

upload_directory () {
	echo -e "\nGetting Local Path for upload..."
	get_file_path
	get_datacenter
	get_cloud_container
	create_container
	upload_files_into_container
}

download_container () {
	echo -e "\nGetting Local Path to download files to..."
	get_file_path
	check_download_path
	get_datacenter
	get_cloud_container
	download_files_from_container
}

remove_container () {
	get_datacenter
	get_cloud_container
	echo -e "\nAre you sure? (y|n)"
	read confirm_delete
	if [[ -n "$confirm_delete" && ("$confirm_delete" == "y" || "$confirm_delete" == "Y") ]]; then
		echo -e "\nContinuing..."
		delete_files_from_container
	else
		echo -e "\nStopping...going back to menu"
	fi
}

main_menu () {
	main_menu_option="";
	temp_variable="";
	while [[ "$main_menu_option" != "q" && "$main_menu_option" != "Q" ]]; do
		echo -e "\nSelect an Option to begin
1) Upload Directory to Cloud Files
2) Download Container from Cloud Files
3) Delete All Files from Container in Cloud Files
Q) Quit"

		read main_menu_option
		case "$main_menu_option" in
			1) upload_directory;;
			2) download_container;;
			3) remove_container;;
			q)  echo -e "\nClosing Application\n"
				temp_variable="NO";;
			Q)  echo -e "\nClosing Application\n"
				temp_variable="NO";;
			*) echo "Invalid Option";;
		esac

		if [ "$temp_variable" != "NO" ]; then
			echo "-- Enter to Continue --"
			read temp_variable
		fi
	done
}

echo -e "\nCloud Files helper script"
echo -e "If you are downloading or uploading large amounts of data use ServiceNet from a Cloud Server in the same DC"

username=$1;
key=$2;

if [ -z $username ]
then
	echo -e "You can pass the username and API Key at runtime of the script as follows:\nUsage: script <Username> <API Key>"
	echo -e "\nGetting Account Credentials..."
	echo -e "\nEnter Username:"
	read username
fi
if [ -z $key ]
then
	echo -e "\nEnter API Key"
	read key
fi

echo -e "\nAre you using ServiceNet?\n1) Yes\n2) No"
read access_point
case "$access_point" in
	1) access_point="yes";;
	2) access_point="no";;
	*) echo -e "\Will use Public Access to Cloud Files"
	   access_point="no";;
esac

getToken

if [ -z $token ]; then
	echo -e "Token not found...exiting"
	exit
else
	main_menu
fi
