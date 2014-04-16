#!/usr/bin/ksh
###############################################################################
# Purpose:  To have a common secure remote PowerHA cluster status monitor which 
# does not use clinfo and provides a different degree of flexibility 
# than clstat - in one tool
#
# Description: An 'clstat' alternative monitoring script. See Usage.
# Differences to clstat :	
#	1/. Designed to be configurable by the end user
#	2/. Cmd line script, produces both text std out and cgi
#	3/. Output can be changed by to remove network/address information [-n]
#	    and show offline Resource Groups [-o]
#	4/. Run on Linux and AIX
#
#	Based on LiveHA - http://www.powerha.lpar.co.uk
# 
#
# Version:  1.000 
#
# Author:   Marcos Jean Sampaio - msampaio@br.ibm.com/mjsamp@gmail.com
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
NODES="node1 node2"
OSTYPE=`uname`
HACMPDEFS="/hacmp.defs"

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
#  Identify OS and defines snmp command
#
###############################################################################


case $OSTYPE in
 
  AIX)
     if [[ -f $HACMPDEFS ]];then
  	SNMPCMD="snmpinfo -m dump -t 1 -v -c $COMMUNITY -o $HACMPDEFS -h" 
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
#  Name: format_cgi
#
#  Create the cgi (on the fly!)
#
###############################################################################
format_cgi()
{

echo '#!/usr/bin/ksh
print "Content-type: text/html\n";' > $CGIFILE

ex -s $CGIFILE <<EOF
a

cat $HTMLFILE | sed '1s:^:<h3>:' | sed '1s:$:</h3>:' | sed 's:UNSTABLE:<font color="#FDD017"><blink>UNSTABLE</blink><font color="#ffffff">:g'| sed 's:JOINING:<font color="#FDD017"><blink>JOINING</blink><font color="#ffffff">:g' | sed 's:LEAVING:<font color="#FDD017"><blink>LEAVING</blink><font color="#ffffff">:g' | sed 's: STABLE:<font color="#00FF00"> STABLE<font color="#ffffff">:g' | sed 's/qn:/<font color="#2B65EC">qn:<font color="#ffffff">/g' | sed 's:UP:<font color="#00FF00">UP<font color="#ffffff">:g' | sed 's:DOWN:<font color="#FF0000"><blink>DOWN</blink><font color="#ffffff">:g'| sed 's:ONLINE:<font color="#00FF00">ONLINE<font color="#ffffff">:g' | sed 's:OFFLINE:<font color="#0000FF"><blink>OFFLINE</blink><font color="#ffffff">:g' > $STATFILE

grep DOWN $HTMLFILE > /dev/null
if [ "\$?" -eq 0 ];then
echo "<audio autoplay loop>
<source src="../tos-redalert.wav" />
<audio/>" >> $STATFILE
fi

cat << EOM
<HTML>
<META HTTP-EQUIV="REFRESH" CONTENT="10">
<HEAD><TITLE>Cluster Status Monitor</TITLE>
<script type="text/javascript">
<!--
t=500;
na=document.all.tags("blink");
flag=1;
bringBackBlinky();
function bringBackBlinky() {
if (flag == 1) {
show="visible";
flag=0;
}
else {
show="hidden";
flag=1;
}
for(i=0;i<na.length;i++) {
na[i].style.visibility=show;
}
setTimeout("bringBackBlinky()", t);
}
-->
</script>
<BODY COLOR="#ffffff" LINK="red" VLINK="blue" BGCOLOR="#000000">
<PRE>
<font COLOR="#ffffff">
<HR SIZE=3>
<font size="3.5"><font face="verdana">
<div style="padding-left: 11em;">
EOM
cat $STATFILE
echo "<div/>"
.
wq
EOF
chmod 755 $CGIFILE

}

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
 
            case $address_state in
                2)
		  printf "UP\n"
                  ;;
                4)
		  printf "DOWN\n"
                  ;;
                *)
		  printf "UNKNOWN\n"
                  ;;
            esac
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

echo ""
echo "  Resource Groups :" 

RGS_COUNT=$($SNMPCMD $1 $RG_NAME | wc -l)
i=0
while [[ $i -le $RGS_COUNT ]]
do

i=$((i+1))

`IFS="\n"; echo $RG_MIB_FUNC | egrep "$RG_NODE_STATE.$i.$node_id = 2|resGroupNodeState.$i.$node_id = 2" > /dev/null 2>&1`
if [ $? -eq 0 ];then

	echo "	"$(IFS="\n"; echo $RG_MIB_FUNC | egrep "$RG_NAME.$i|resGroupName.$i" | awk '{print $3}' | sed 's/"//g') "	"State: ONLINE

fi

`IFS="\n"; echo $RG_MIB_FUNC | egrep "$RG_NODE_STATE.$i.$node_id = 32|resGroupNodeState.$i.$node_id = 32" > /dev/null 2>&1`
if [ $? -eq 0 ];then

	echo "	"$(IFS="\n"; echo $RG_MIB_FUNC | egrep "$RG_NAME.$i|resGroupName.$i" | awk '{print $3}' | sed 's/"//g') "	"State: LEAVING

fi

`IFS="\n"; echo $RG_MIB_FUNC | egrep "$RG_NODE_STATE.$i.$node_id = 16|resGroupNodeState.$i.$node_id = 16" > /dev/null 2>&1`
if [ $? -eq 0 ];then

	echo "	"$(IFS="\n"; echo $RG_MIB_FUNC | egrep "$RG_NAME.$i|resGroupName.$i" | awk '{print $3}' | sed 's/"//g') "	"State: JOINING

fi

if [ $OFFLINE = "TRUE" ]; then
	`IFS="\n"; echo $RG_MIB_FUNC | egrep "$RG_NODE_STATE.$i.$node_id = 4|resGroupNodeState.$i.$node_id = 4" > /dev/null 2>&1`
	if [ $? -eq 0 ];then

		echo "	"$(IFS="\n"; echo $RG_MIB_FUNC | egrep "$RG_NAME.$i|resGroupName.$i" | awk '{print $3}' | sed 's/"//g') "	"State: OFFLINE

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
    case $network_state in
        2)
	  printf "UP\n"
          ;;
        4)
	  printf "DOWN\n"
          ;;
        32)
	  printf "JOINING\n"
          ;;
        64)
	  printf "LEAVING\n"
          ;;
        *)
	  printf "N/A\n"
          ;;
    esac

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

    case $node_state in
        2)
	  printf "UP $finternal_state\n"
          ;;
        4)
	  printf "DOWN $finternal_state\n"
          ;;
        32)
	  printf "JOINING $finternal_state\n"
          ;;
        64)
	  printf "LEAVING $finternal_state\n"
          ;;
    esac
    
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

  cluster_state=$(echo "$CLUSTER_MIB" | egrep -w "$CLUSTER_STATE\.0|clusterState.0" | cut -f3 -d" ")
  cluster_substate=$(echo "$CLUSTER_MIB" | egrep -w "$CLUSTER_SUBSTATE\.0|clusterSubState.0" | cut -f3 -d" ")

  case $cluster_state in
	2)
	  cs="UP"
	  ;;
	4)
	  cs="DOWN"
	  ;;
  esac

  case $cluster_substate in
	4)
	  css="DOWN"
	  ;;
	8)
	  css="UNKNOWN"
	  ;;
	16)
	  css="UNSTABLE"
	  ;;
	2 | 32)
	  css="STABLE"
	  ;;
	64)
	  css="ERROR"
	  ;;
	128)
	  css="RECONFIG"
	  ;;
  esac

echo "Status for $cluster_name on $(date +%d" "%b" "%y" "%T)" 
echo  "Cluster is ($cs & $css)    qn: $HANODE" 

cluster_num_nodes=$(echo "$CLUSTER_MIB" | egrep -w "$CLUSTER_NUM_NODES\.0|clusterNumNodes.0" | cut -f3 -d" ")

print_node_info $1


}



get_node ()
{

	VALUES=""
        while [ $# -ne 0 ]
        do
        	ping -w 3 -c 1 $1 > /dev/null 2>&1
        	if [ $? -eq 0 ]; then        	
        		CLUSTER_MIB=$($SNMPCMD $1 1.3.6.1.4.1.2.3.1.2.1.5 2> /dev/null)
        		LOGFILE="/tmp/$1.qhaslog"
			HTMLFILE="/tmp/$1.qhashtml"
			CGIFILE="/usr/IBMAHS/cgi-bin/`basename ${0}|cut -d "." -f 1`.cgi"
			STATFILE="/tmp/$1.aastat"
        		
        		# is there any snmp info?
	  		snmpinfocheck=`echo $CLUSTER_MIB | egrep "$CLUSTER_BRANCH|^cluster"`
	  		if [[ $? -eq 0 && $snmpinfocheck != "" ]]; then
                		print_cluster_info $1 > $LOGFILE
                		cat $LOGFILE 
				cp $LOGFILE $HTMLFILE
          		else
                		echo "Data unavailable on NODE: $1 
				$(date +%d" "%b" "%y" "%T)
				Check cluster node state" | tee $HTMLFILE
				#service clsmon reload-script `basename $0` &
				shift
          		fi

			format_cgi
        	else
        		VALUES="$VALUES $1 "
        		shift   
        	fi
        done
        
        echo "Warning: nodes $VALUES are not responding.
        	$(date +%d" "%b" "%y" "%T)" | tee $HTMLFILE
        

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


while true
do

	get_node $NODES

done

exit 0
