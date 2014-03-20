#!/bin/bash

# Extended from Dave Kludt's limits-linuxv2.sh script:
# https://github.rackspace.com/davi4261/Custom-Scripts/blob/master/limits-linuxv2.sh

#Get limits for account First Gen, and Next Gen Limits for both DCs. If using custom limits for FG then some limits will not show.

#Variables to store the account information. First item in each all go together, then the next to allow for stringing multiple accounts together.
#Space seperated list, and just replace the values.
ddi=(DDI);
key=(API-KEY);
username=(USERNAME);

#Function get the token after an auth call for the correct account.
getToken () {

    ddi=$1
    key=$2
    username=$3
    token=`/usr/bin/curl -s -XPOST -H "Content-Type: application/json" -d '{"auth":{"RAX-KSKEY:apiKeyCredentials":{"username":"'$username'","apiKey":"'$key'"}}}' https://identity.api.rackspacecloud.com/v2.0/tokens | grep -m1 -oP '(?<="token":{"id":")[^"]*'`;
}


#Function to get the limits for the respective data center. Argument passed in function call
dcInfo () {

    datacenter=$1
    generation=$2

    if [ $generation == "firstgen" ];
    then
        firstGenRan=1
        limits=`/usr/bin/curl -s -XGET -H "X-Auth-Token: $token" https://servers.api.rackspacecloud.com/v1.0/$ddi/limits`
        servers=`/usr/bin/curl -s -XGET -H "X-Auth-Token: $token" https://servers.api.rackspacecloud.com/v1.0/$ddi/servers/detail | grep -oP '(?<="flavorId":)[^,]*'`
        maxRam=`echo $limits | grep -m1 -oP '(?<="maxTotalRAMSize":)[^}]*'`
        limits=`echo $limits | sed 's/{\([0-9][0-9]*\|id\)}//g' | tr '{}' '\n' | egrep 'POST' | tr ' ' '\n'`
        
        serverDayPost=`for item in $limits; do if [ \`echo $item | grep -c 'servers'\` -gt 0 ]; then echo $item; fi done`
        serverDayPostRemain=`echo $serverDayPost | grep -oP '(?<="remaining":)\d+'`
        serverDayPostTotal=`echo $serverDayPost | grep -oP '(?<="value":)\d+'`

        allMinutePost=`for item in $limits; do if [ \`echo $item | grep -c '"\.\*"'\` -gt 0 ]; then echo $item; fi done`
        allMinutePostRemain=`echo $allMinutePost | grep -oP '(?<="remaining":)\d+'`
        allMinutePostTotal=`echo $allMinutePost | grep -oP '(?<="value":)\d+'`                        
    elif [ $generation == "nextgen" ]
    then
        limits=`/usr/bin/curl -s -XGET -H "X-Auth-Token: $token" https://$datacenter.servers.api.rackspacecloud.com/v2/$ddi/limits`
        maxInstances=`echo $limits | grep -m1 -oP '(?<="maxTotalInstances" : )[^",]*'`
        maxRam=`echo $limits | grep -m1 -oP '(?<="maxTotalRAMSize" : )[^",}]*'`
        servers=`/usr/bin/curl -s -XGET -H "X-Auth-Token: $token" https://$datacenter.servers.api.rackspacecloud.com/v2/$ddi/servers/detail | grep -m1 -oP '(?<="flavor": {"id": ")[^"]*'`

        limits=`echo $limits | sed 's/{\([0-9][0-9]*\|id\)}//g' | tr '{}' '\n' | egrep 'POST|GET|"uri" :' | while read LINE; do if [ \`echo $LINE | grep -c regex\` -gt 0 ]; then URI="$LINE"; else echo "$URI $LINE ]\n"; fi done | sed 's/^.*"uri"/"uri"/'`

        serverDayPost=`echo -e $limits | while read LINE; do if [ \`echo $LINE | grep -c '"/servers"'\` -gt 0 ]; then echo $LINE; fi done`
        serverDayPostRemain=`echo $serverDayPost | grep -oP '(?<="remaining" : )\d+'`
        serverDayPostTotal=`echo $serverDayPost | grep -oP '(?<="value" : )\d+'`
        
        allMinuteGet=`echo -e $limits | while read LINE; do if [ \`echo $LINE | grep '"uri" : "\*"' | grep -c '"GET"' \` -gt 0 ]; then echo $LINE; fi done`
        allMinuteGetRemain=`echo $allMinuteGet | grep -oP '(?<="remaining" : )\d+'`
        allMinuteGetTotal=`echo $allMinuteGet | grep -oP '(?<="value" : )\d+'`

        allMinutePost=`echo -e $limits | while read LINE; do if [ \`echo $LINE | grep '"uri" : "\*"' | grep -c '"POST"' \` -gt 0 ]; then echo $LINE; fi done`
        allMinutePostRemain=`echo $allMinutePost | grep -oP '(?<="remaining" : )\d+'`
        allMinutePostTotal=`echo $allMinutePost | grep -oP '(?<="value" : )\d+'`
    fi

}

#Function adds the total RAM for all servers using the API to grab the total. Uses flavor ID's to gather total RAM
totalRam() {
    totalInstances=0
    totalRamUsed=0
    servers=("${@}")

    for x in "${servers[@]}"
    do
        (( totalInstances += 1 ))
        if [ $x == 1 ]
        then
            #256M
            (( totalRamUsed += 256 ))
        elif [ $x == 2 ]
        then
            #512M
            (( totalRamUsed += 512 ))
        elif [ $x == 3 ]
        then
            #1GB
            (( totalRamUsed += 1024 ))
        elif [ $x == 4 ]
        then
            #2GB
            (( totalRamUsed += 2048 ))
        elif [ $x == 5 ]
        then
            #4GB
            (( totalRamUsed += 4096 ))
        elif [ $x == 6 ]
        then
            #8GB
            (( totalRamUsed += 8192 ))
        elif [ $x == 7 ]
        then
            #16GB
            (( totalRamUsed += 16384 ))
        elif [ $x == 8 ]
        then
            #30GB
            (( totalRamUsed += 30720 ))
        fi
    done
}

#Main For loop to go through the accounts.
for item in ${!ddi[*]}
do
    getToken ${ddi[$item]} ${key[$item]} ${username[$item]}
    dcInfo "dfw" "nextgen"
    dfwMaxInstances=$maxInstances
    dfwMaxRam=$maxRam
    dfwservers=$servers

    dfwserverDayPostRemain=$serverDayPostRemain
    dfwserverDayPostTotal=$serverDayPostTotal
    dfwallMinuteGetRemain=$allMinuteGetRemain
    dfwallMinuteGetTotal=$allMinuteGetTotal
    dfwallMinutePostRemain=$allMinutePostRemain
    dfwallMinutePostTotal=$allMinutePostTotal

    totalRam $dfwservers
    dfwtotalRamUsed=$totalRamUsed
    dfwtotalInstances=$totalInstances
    dfwRemainingRam=(`echo "$dfwMaxRam - $dfwtotalRamUsed" | bc`)

    dcInfo "default" "firstgen"
    fgallMinutePostRemain=$allMinutePostRemain
    fgallMinutePostTotal=$allMinutePostTotal
    fgserverDayPostTotal=$serverDayPostTotal
    fgserverDayPostRemain=$serverDayPostRemain
    fgMaxRam=$maxRam
    fgservers=$servers
    
    totalRam $fgservers
    fgtotalRamUsed=$totalRamUsed
    fgtotalInstances=$totalInstances
    fgRemainingRam=(`echo "$fgMaxRam - $fgtotalRamUsed" | bc`)

    dcInfo "ord" "nextgen"
    ordMaxInstances=$maxInstances
    ordMaxRam=$maxRam
    ordservers=$servers

    ordserverDayPostRemain=$serverDayPostRemain
    ordserverDayPostTotal=$serverDayPostTotal
    ordallMinuteGetRemain=$allMinuteGetRemain
    ordallMinuteGetTotal=$allMinuteGetTotal
    ordallMinutePostRemain=$allMinutePostRemain
    ordallMinutePostTotal=$allMinutePostTotal


    totalRam $ordservers
    ordtotalRamUsed=$totalRamUsed
    ordtotalInstances=$totalInstances
    ordRemainingRam=(`echo "$ordMaxRam - $ordtotalRamUsed" | bc`)

    echo -e "    ------------------------------------------------
    \n    FirstGen API Limits for Account: $ddi - $username\n
    -------------------------------------------------\n
    Number of Instances: $fgtotalInstances\n
    RAM Max Total: $fgMaxRam
    RAM Used: $fgtotalRamUsed
    RAM Remaining: $fgRemainingRam\n
    Posts / Day: $fgserverDayPostTotal
    Remaining: $fgserverDayPostRemain\n
    Posts / Minute: $fgallMinutePostTotal
    Remaining: $fgallMinutePostRemain\n
    ------------------------------------------------
    \n    NextGen API Limits for Account: $ddi - $username\n
    -------------------------------------------------\n
    Datacenter: DFW\n
    Max Total Instances: $dfwMaxInstances
    Number of Instances: $dfwtotalInstances\n
    RAM Max Total: $dfwMaxRam
    RAM Used: $dfwtotalRamUsed
    RAM Remaining: $dfwRemainingRam\n
    Posts / Day: $dfwserverDayPostTotal
    Remaining: $dfwserverDayPostRemain\n
    Posts / Minute: $dfwallMinutePostTotal
    Remaining: $dfwallMinutePostRemain\n
    Gets / Minute: $dfwallMinuteGetTotal
    Gets Remaining: $dfwallMinuteGetRemain\n
    -------------------------------------------------\n
    Datacenter: ORD\n
    Max Total Instances: $ordMaxInstances
    Number of Instances: $ordtotalInstances\n
    RAM Max Total: $ordMaxRam
    RAM Used: $ordtotalRamUsed
    RAM Remaining: $ordRemainingRam\n
    Posts / Day: $ordserverDayPostTotal
    Remaining: $ordserverDayPostRemain\n
    Posts / Minute: $ordallMinutePostTotal
    Remaining: $ordallMinutePostRemain\n
    Gets / Minute: $ordallMinuteGetTotal
    Gets Remaining: $ordallMinuteGetRemain\n"

done

