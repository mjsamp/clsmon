#!/usr/bin/ksh
###############################################################################
# Purpose:  To have a common secure remote PowerHA cluster status monitor which 
# does not use clinfo and provides a different degree of flexibility 
# than clstat - in one tool
#
# Description: An 'clstat' alternative monitoring script. See Usage.
# Differences to clstat :	
#	1/. Designed to be configurable by the end user
#	2/. Cmd line script, produces both text std out and Web html
#	3/. Output can be changed by to remove network/address information [-n]
#	    and show offline Resource Groups [-o]
#	4/. Run on Linux and AIX
#
#	Based on LiveHA - http://www.powerha.lpar.co.uk
# 
#
# Version:  2.000 
#
# Author:   Marcos Jean Sampaio - mjsamp@gmail.com
###############################################################################

usage()
{
    printf "Usage: $PROGNAME [-n]\n"
    printf "\t-o Show offline Resource Groups\n" 
    printf "\t-n Omit Network info\n" 
    exit 1
}

###############################################################################
# 
#  Global VARs
#
###############################################################################

#*******************Please Alter the VARs below as appropriate*****

COMMUNITY="public"
NODES="192.168.123.100 192.168.123.102"
OSTYPE=`uname`
HACMPDEFS="/hacmp.defs"
cluster_name="aix_cluster"
static_name=$cluster_name
HTMLFILE="/var/www/clsmon/$cluster_name.html"
CSVFILE="/var/www/clsmon/clusters.csv"
CSV=$static_name',UNKNOWN,UNKNOWN,0'
REFRESH=5
SEDCMD="/bin/sed -i"
counter=0

#******ONLY alter the code below this line, if you want to change******
#********************this behaviour of this script*********************


PROGNAME=$(basename ${0})


# set up some global variables with SNMP branch info
# cluster
  CLUSTER_BRANCH="1.3.6.1.4.1.2.3.1.2.1.5.1"
  CLUSTER_NAME="$CLUSTER_BRANCH.2"
  CLUSTER_STATE="$CLUSTER_BRANCH.4"
  CLUSTER_SUBSTATE="$CLUSTER_BRANCH.8"
  CLUSTER_NUM_NODES="$CLUSTER_BRANCH.11"
# node
  NODE_BRANCH="1.3.6.1.4.1.2.3.1.2.1.5.2.1.1"
  NODE_ID="$NODE_BRANCH.1"
  NODE_STATE="$NODE_BRANCH.2"
  NODE_NUM_IF="$NODE_BRANCH.3"
  NODE_NAME="$NODE_BRANCH.4"
# network
  NETWORK_BRANCH="1.3.6.1.4.1.2.3.1.2.1.5.4.1.1"
  NETWORK_ID="$NETWORK_BRANCH.2"
  NETWORK_NAME="$NETWORK_BRANCH.3"
  NETWORK_ATTRIBUTE="$NETWORK_BRANCH.4"
  NETWORK_STATE="$NETWORK_BRANCH.5"
# address
  ADDRESS_BRANCH="1.3.6.1.4.1.2.3.1.2.1.5.3.1.1"
  ADDRESS_IP="$ADDRESS_BRANCH.2"
  ADDRESS_LABEL="$ADDRESS_BRANCH.3"
  ADDRESS_NET="$ADDRESS_BRANCH.5"
  ADDRESS_STATE="$ADDRESS_BRANCH.6"
  ADDRESS_ACTIVE_NODE="$ADDRESS_BRANCH.7"
# resource group
  RG_BRANCH="1.3.6.1.4.1.2.3.1.2.1.5.11"
  RG_ID="$RG_BRANCH.1.1.1"
  RG_NAME="$RG_BRANCH.1.1.2"
  RG_NODE_STATE="$RG_BRANCH.3.1.3"



###############################################################################
# 
#  Identify OS and defines snmp and sed commands path
#
###############################################################################


case $OSTYPE in
 
  AIX)
     if [[ -f $HACMPDEFS ]];then
  	SNMPCMD="snmpinfo -m dump -t 1 -v -c $COMMUNITY -o $HACMPDEFS -h"
  	SEDCMD="/opt/freeware/bin/sed -i"
     else
  	echo "$HACMPDEFS file not found. Exiting." ; exit
     fi
  ;;
  
  Linux) 
     SNMPCMD="snmpwalk -c $COMMUNITY -O faUnQ -v 1"
  ;;
  
  *)
     echo "$OSTYPE is not supported. Exiting." ; exit
  ;;

esac


###############################################################################
# 
#  Name: print_address_info
#
#  Prints the address information for the node and network given in the
#  environment
#
###############################################################################
print_address_info()
{
  [[ "$VERBOSE_LOGGING" = "high" ]] && set -x

  # Get key (IP addresses) from MIB
  addresses=$(echo "$ADDRESS_MIB_FUNC" | egrep -w "$ADDRESS_IP.$node_id|addrAddress.$node_id" | uniq | sort | cut -f3 -d" ")

  # Get the active Node for each IP address
  for address in $addresses
  do
    address_net_id=$(echo "$ADDRESS_MIB_FUNC" | egrep -w "$ADDRESS_NET.$node_id.$address|addrNetId.$node_id.$address" | cut -f3 -d" ")
    
    if [[ "$address_net_id" = "$net_id" ]]
    then
	active_node=$(echo "$ADDRESS_MIB_FUNC" | egrep -w "$ADDRESS_ACTIVE_NODE.$node_id.$address|addrActiveNode.$node_id.$address" | cut -f3 -d" ")

        if [[ "$active_node" = $node_id ]]
        then
	    address_label=$(echo "$ADDRESS_MIB_FUNC" | egrep -w "$ADDRESS_LABEL.$node_id.$address|addrLabel.$node_id.$address" | cut -f2 -d\")
	    address_state=$(echo "$ADDRESS_MIB_FUNC" | egrep -w "$ADDRESS_STATE.$node_id.$address|addrState.$node_id.$address" | cut -f3 -d" ")
	    printf "\t%-15s %-20s " $address $address_label
	    table+='
	      <tr>
            <td class="tg-f4iu">'$address' '$address_label'</td>
	    '
 
            case $address_state in
                2)
		  printf "UP\n"
		  table+='<td class="tg-7f8f">UP</td>'
                  ;;
                4)
		  printf "DOWN\n"
		  table+='<td class="tg-4rdo">DOWN</td>'
                  ;;
                *)
		  printf "UNKNOWN\n"
		  table+='<td class="tg-io23">UNKNOWN</td>'
                  ;;
            esac
            table+='</tr>'
        fi
    fi

  done
}

###############################################################################
# 
#  Name: print_rg_info
#
#  Prints the RGs status info.
#
###############################################################################
print_rg_info()
{

RG_MIB_FUNC=$CLUSTER_MIB



RGS_COUNT=$($SNMPCMD $1 $RG_NAME | wc -l)
if [[ $RGS_COUNT -gt 0 ]];then
    echo ""
    echo "  Resource Groups :"
        table+='
        <tr>
            <td class="tg-12d8">Resourse Groups:</td>
            <td class="tg-12d8"></td>
        </tr>
        '
fi

i=0
while [[ $i -le $RGS_COUNT ]]
do

i=$((i+1))

    rgname=$(IFS="\n"; echo $RG_MIB_FUNC | egrep "$RG_NAME.$i|resGroupName.$i" | awk '{print $3}' | sed 's/"//g')

`IFS="\n"; echo $RG_MIB_FUNC | egrep "$RG_NODE_STATE.$i.$node_id = 2|resGroupNodeState.$i.$node_id = 2" > /dev/null 2>&1`
if [ $? -eq 0 ];then

	echo "	"$rgname "	"State: ONLINE
		table+='
	      <tr>
            <td class="tg-f4iu">'$rgname'</td>
            <td class="tg-7f8f">ONLINE</td>
          </tr>
	    '

fi

`IFS="\n"; echo $RG_MIB_FUNC | egrep "$RG_NODE_STATE.$i.$node_id = 32|resGroupNodeState.$i.$node_id = 32" > /dev/null 2>&1`
if [ $? -eq 0 ];then
    
	echo "	"$rgname "	"State: LEAVING
		table+='
	      <tr>
            <td class="tg-f4iu">'$rgname'</td>
            <td class="tg-io23">LEAVING</td>
          </tr>
	    '
fi

`IFS="\n"; echo $RG_MIB_FUNC | egrep "$RG_NODE_STATE.$i.$node_id = 16|resGroupNodeState.$i.$node_id = 16" > /dev/null 2>&1`
if [ $? -eq 0 ];then

	echo "	"$rgname "	"State: JOINING
		table+='
	      <tr>
            <td class="tg-f4iu">'$rgname'</td>
            <td class="tg-io23">JOINING</td>
          </tr>
	    '
fi

if [ $OFFLINE = "TRUE" ]; then
	`IFS="\n"; echo $RG_MIB_FUNC | egrep "$RG_NODE_STATE.$i.$node_id = 4|resGroupNodeState.$i.$node_id = 4" > /dev/null 2>&1`
	if [ $? -eq 0 ];then

		echo "	"$rgname "	"State: OFFLINE
		table+='
	      <tr>
            <td class="tg-f4iu">'$rgname'</td>
            <td class="tg-4rdo">OFFLINE</td>
          </tr>
	    '

	fi
fi

done

}

###############################################################################
# 
#  Name: print_network_info
#
#  Prints the network information for the node given in the environment
#
###############################################################################
print_network_info()
{


  [[ "$VERBOSE_LOGGING" = "high" ]] && set -x

  # Get network IDs
   network_ids=$(echo "$NETWORK_MIB_FUNC" | egrep -w "$NETWORK_ID.$node_id|netId.$node_id" | cut -f3 -d" " | uniq | sort -n )

  # Get states for these networks on this node
  for net_id in $network_ids
  do 
    printf "\n"
    network_name=$(echo "$NETWORK_MIB_FUNC" | egrep -w "$NETWORK_NAME.$node_id.$net_id|netName.$node_id.$net_id" | cut -f2 -d\")
    network_attribute=$(echo "$NETWORK_MIB_FUNC" | egrep -w "$NETWORK_ATTRIBUTE.$node_id.$net_id|netAttribute.$node_id.$net_id" | cut -f3 -d" ")
    network_state=$(echo "$NETWORK_MIB_FUNC" | egrep -w "$NETWORK_STATE.$node_id.$net_id|netState.$node_id.$net_id" | cut -f3 -d" ")
    formatted_network_name=$(echo "$network_name" | awk '{printf  "%-18s", $1}')

    printf "  Network : $formatted_network_name State: " "$formatted_network_name"
    table+='
    <tr>
        <td class="tg-12d8">Network: '$formatted_network_name'</td>
    '
    case $network_state in
        2)
	  printf "UP\n"
	  table+='<td class="tg-m7lx">UP</td>'
          ;;
        4)
	  printf "DOWN\n"
	  table+='<td class="tg-4rdo">DOWN</td>'
          ;;
        32)
	  printf "JOINING\n"
	  table+='<td class="tg-io23">JOINING<br></td>'
          ;;
        64)
	  printf "LEAVING\n"
	  table+='<td class="tg-io23">LEAVING<br></td>'
          ;;
        *)
	  printf "N/A\n"
	  table+='<td class="tg-io23">N/A<br></td>'
          ;;
    esac
    table+='</tr>'
    PRINT_IP_ADDRESS="true"

    # If serial type network, then don't attempt to print IP Address
    [[ $network_attribute -eq 4 ]] && PRINT_IP_ADDRESS="false"
    
    print_address_info

  done
}


###############################################################################
# 
#  Name: print_node_info
#
#  Prints the node information for each node found in the MIB
#
###############################################################################
print_node_info()
{

  [[ "$VERBOSE_LOGGING" = "high" ]] && set -x
  
  NODE_MIB=$CLUSTER_MIB
  NETWORK_MIB=$CLUSTER_MIB
  ADDRESS_MIB=$CLUSTER_MIB
  

  NODE_ID_COUNTER=0
  CSV=$cluster_name','$cs','$css','$cluster_num_nodes
  while [[ $cluster_num_nodes -ne 0 ]]
  do
    # Get node information for each node
    node_id=$(echo "$NODE_MIB" | egrep -w "$NODE_ID.$NODE_ID_COUNTER|^nodeId.$NODE_ID_COUNTER" | cut -f3 -d " ")

    let NODE_ID_COUNTER=NODE_ID_COUNTER+1

    # Node ids may not be contiguous
    if [[ -z "$node_id" ]]  
    then
	continue
    fi
    
    node_state=$(echo "$NODE_MIB" | egrep -w "$NODE_STATE.$node_id|^nodeState.$node_id" | cut -f3 -d" ")
    node_num_if=$(echo "$NODE_MIB" | egrep -w "$NODE_NUM_IF.$node_id|^nodeNumIf.$node_id" | cut -f3 -d" ")
    node_name=$(echo "$NODE_MIB" | egrep -w "$NODE_NAME.$node_id|^nodeName.$node_id" | cut -f2 -d\")
    formatted_node_name=$(echo "$node_name" | awk '{printf  "%-15s", $1}')

    echo ""
    printf "Node : $formatted_node_name State: " "$formatted_node_name"
    table+='
    <div style="display: inline-flex">
    <table class="tg" style="margin-left: 5px">
    <thead> 
    <tr>
        <td class="tg-njvp">Node: '$formatted_node_name'</td>
    '

    case $node_state in
        2)
	  printf "UP $finternal_state\n"
	  table+='<td class="tg-6ug1"><span style="background: #56CA36;padding: 2px;color: black">UP</span></td>'
          ;;
        4)
	  printf "DOWN $finternal_state\n"
	  table+='<td class="tg-qrnh"><span style="background: red;padding: 2px;color: white">DOWN</span></td>'
          ;;
        32)
	  printf "JOINING $finternal_state\n"
	  table+='<td class="tg-io23"><span style="background: yellow;padding: 2px;color: black">JOINING</span></td>'
          ;;
        64)
	  printf "LEAVING $finternal_state\n"
	  table+='<td class="tg-io23"><span style="background: yellow;padding: 2px;color: black">LEAVING</span></td>'
          ;;
    esac
    
      table+='</tr>
            </thead>
            <tbody>
      '
    
    NETWORK_MIB_FUNC=$NETWORK_MIB #`echo "$NETWORK_MIB" | egrep "$NETWORK_BRANCH\..\.$node_id|net*\..\.$node_id"`
    ADDRESS_MIB_FUNC=$ADDRESS_MIB #`echo "$ADDRESS_MIB" | egrep "$ADDRESS_BRANCH\..\.$node_id|addr*\..\.$node_id"`

    if [ $NETWORK = "TRUE" ]; then
     print_network_info
    fi
     print_rg_info $1

    let cluster_num_nodes=cluster_num_nodes-1

  done

}


###############################################################################
# 
#  Name: print_cluster_info
#
#  Prints the cluster information for the cluster found in the MIB of which
#  this node is a member.
#
###############################################################################
print_cluster_info ()
{
  HANODE=$1

  cluster_name=$(echo "$CLUSTER_MIB" | egrep -w "$CLUSTER_NAME\.0|clusterName.0" | cut -f2 -d\")
  
if [[ $cluster_name != "" ]]; then

  cluster_state=$(echo "$CLUSTER_MIB" | egrep -w "$CLUSTER_STATE\.0|clusterState.0" | cut -f3 -d" ")
  cluster_substate=$(echo "$CLUSTER_MIB" | egrep -w "$CLUSTER_SUBSTATE\.0|clusterSubState.0" | cut -f3 -d" ")

  case $cluster_state in
	2)
	  cs="UP"
	  csb="#56CA36"
	  ;;
	4)
	  cs="DOWN"
	  csb="red"
	  ;;
  esac

  case $cluster_substate in
	4)
	  css="DOWN"
	  cssb="red"
	  ;;
	8)
	  css="UNKNOWN"
	  cssb="yellow"
	  ;;
	16)
	  css="UNSTABLE"
	  cssb="yellow"
	  ;;
	2 | 32)
	  css="STABLE"
	  cssb="#56CA36"
	  ;;
	64)
	  css="ERROR"
	  cssb="red"
	  ;;
	128)
	  css="RECONFIG"
	  cssb="yellow"
	  ;;
  esac

echo "Status for $cluster_name at $(date +%b" "%d" "%T)" 
echo  "Cluster is ($cs & $css)    qn: $HANODE"

table='
<div style="margin-left: 5px;display: grid">
<table class="tg"><thead>
  <tr>
'

#table+='<th class="tg-2xbj" colspan="2">Status for <span style="background: #1723D0;padding: 2px">'$cluster_name'</span> at '`date +%b" "%d" "%T`'</th>
table+='<th class="tg-2xbj" colspan="2">Status for '$cluster_name' at '`date +%b" "%d" "%T`'</th>
  </tr></thead>
  <tbody>'
  
table+='
  <tr>
    <td class="tg-08qx">Cluster is <span style="background: '$csb';padding: 2px">'$cs'</span> and <span style="background: '$cssb';padding: 2px">'$css'</span></td>
    <td class="tg-08qx">qn: '$HANODE'</td>
  </tr>
  </tbody>
</table>
</div>
<br><br>
'



cluster_num_nodes=$(echo "$CLUSTER_MIB" | egrep -w "$CLUSTER_NUM_NODES\.0|clusterNumNodes.0" | cut -f3 -d" ")
print_node_info $1

else

table='
        <div class="jumbotron" style="color:black">
        </div>
'
cluster_num_nodes=$(echo "$CLUSTER_MIB" | egrep -w "$CLUSTER_NUM_NODES\.0|clusterNumNodes.0" | cut -f3 -d" ")
  
  CSV=$cluster_name','$cs','$css','$cluster_num_nodes

print_node_info $1

fi

}

format_csv ()
{

    grep "$cluster_name," $CSVFILE > /dev/null 2>&1
    if [ $? -eq 0 ];then
        echo $cluster_name' is on file'
        $SEDCMD 's/.*'$cluster_name',.*/'$CSV'/' $CSVFILE
    else
        echo $cluster_name' is not on file'
        echo $CSV >> $CSVFILE
    fi

}

get_node ()
{

	VALUES=""
        while [ $# -ne 0 ]
        do
            #echo "pinging $1"
        	ping -w 3 -c 1 $1 > /dev/null 2>&1
            	if [ $? -eq 0 ]; then        	
                	CLUSTER_MIB=$($SNMPCMD $1 1.3.6.1.4.1.2.3.1.2.1.5 2> /dev/null)
                	LOGFILE="/tmp/$1.qhaslog"
                	
                	cluster_name=$(echo "$CLUSTER_MIB" | egrep -w "$CLUSTER_NAME\.0|clusterName.0" | cut -f2 -d\")
                		# is there any snmp info?
	          		snmpinfocheck=`echo $CLUSTER_MIB | egrep "$CLUSTER_BRANCH|^cluster"`
	      		#echo "snmp check: $snmpinfocheck"
	          		if [[ $? -eq 0 && $snmpinfocheck != "" && $cluster_name != "" ]]; then
                        		print_cluster_info $1 > $LOGFILE
                        		cat $LOGFILE 

				        echo $table > $HTMLFILE
				        #echo "CSV: "$CSV
				        format_csv
				        sleep $REFRESH
                  	else
                        #		echo "Data unavailable on NODE: $1 
				        #$(date +%d" "%b" "%y" "%T)
				        #Check cluster node state" | tee $HTMLFILE
				        #service clsmon reload-script `basename $0` &
				        table='
                <div class="jumbotron" style="color:black">
				        Node '$1' is up but data is unavailable at 
				        '`date +%b" "%d" "%T`'
				        . Please check cluster services on node.
			    </div>
				        '
                        if [ $counter -gt 99 ];then
                            echo $table > $HTMLFILE
                            CSV=$static_name',UNKNOWN,UNKNOWN,0'
                            cluster_name=$static_name
                            format_csv
                            counter=0
                        fi
				        shift
                  	fi

            	else
            		VALUES="$VALUES $1 "
            		shift   
            	fi
        done
        
        echo "Warning: $VALUES no snmp data at $(date +%b" "%d" "%T). Please check if $NODES are up and cluster services are running."
        table='
                <div class="jumbotron" style="color:black">
                    Warning: '$VALUES' no snmp data at 
                    '`date +%b" "%d" "%T`'. Please check if '$NODES' are up and cluster services are running.
                </div>
        '

        counter=$((counter+1))
        if [ $counter -gt 99 ];then
            echo $table > $HTMLFILE
            CSV=$static_name',UNKNOWN,UNKNOWN,0'
            cluster_name=$static_name
            format_csv
            counter=0
        fi

}


###############################################################################
# Main
###############################################################################

# sort the flags

NETWORK="TRUE"
OFFLINE="FALSE"
while getopts :no ARGs
do
 case $ARGs in
	n) NETWORK="FALSE" ;;
	o) OFFLINE="TRUE" ;;
	\?) printf "\nNot a valid option\n\n" ; usage ; exit ;;
 esac
done

################ get the nodes and start

format_csv #add cluster to clusters.csv file
while true
do

	get_node $NODES

done

exit 0
