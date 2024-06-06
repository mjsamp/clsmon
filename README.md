
       
  # Remote PowerHA cluster status monitor
  
  Provides both text stdout and Web only using snmp traps.

  Runs on Linux and AIX.
 
 	Based on LiveHA - http://www.powerha.lpar.co.uk
  
 
  Version:  2.0
 
  Author:   Marcos Jean Sampaio - mjsamp@gmail.com


## Requirements

ksh (Korn Shell)

HTTP Server (tested in apache only)

GNU sed

snmpwalk (Linux)

snmpinfo (AIX)

The file hacmp.defs (only AIX)

You will find it in a PowerHA node on the following path so you can copy it:
```bash
/usr/es/sbin/cluster/hacmp.defs
```

## HTTP Configurantion example
Considering you have an up and running Apache server on your machine add the following line to your http configuration file: 
```bash
Alias /clsmon /var/www/clsmon

```
Then copy the folder clsmon to your server /var/www folder and change its owner to your http server user:
```bash
chown -R www-data.www-data /var/www/clsmon
```

## Variables

Replace variables in your script to appropriate values to reflect your environment settings.

```bash
COMMUNITY="public"
NODES="node1 192.168.1.1"
HACMPDEFS="/hacmp.defs" --> path to hacmp.defs file (needed only in AIX)
cluster_name="aix_cluster"
HTMLFILE="/var/www/clsmon/$cluster_name.html"
CSVFILE="/var/www/clsmon/clusters.csv"
REFRESH=5
SEDCMD="/bin/sed -i"
```

## Run

Run the script then access the MultiCluster WebView interface on this path:

https://your_web_server/clsmon/index.html


##
## SNMP Configuration
  
  The following steps should be done in every cluster node that will be used as a data source.

It works using snmp v1

```bash
root@node01:/>ls -l /usr/sbin/snmpd
lrwxrwxrwx    1 root     system           17 May 14 10:54 /usr/sbin/snmpd -> /usr/sbin/snmpdv1
```

File /etc/snmpdv3.conf

Enable this MIB sub tree by adding this line in /etc/snmpdv3.conf file.
```bash
VACM_VIEW defaultView 1.3.6.1.4.1.2.3.1.2.1.5 - included -
```

Refresh snmpd service
```bash
stopsrc -s snmpd
startsrc -s snmpd
```

Check if it is returning the cluster data
```bash
snmpinfo -m dump -t 1 -v -c public -o /usr/es/sbin/cluster/hacmp.defs -h node01
```

Sometimes, even after doing this, it still doesn't work. Make sure that this COMMUNITY entry is present in /etc/snmpdv3.conf:
```bash
COMMUNITY public public noAuthNoPriv 0.0.0.0 0.0.0.0 -
```

Then reconfigure and refresh the services
```bash
stopsrc -s hostmibd
stopsrc -s snmpmibd
stopsrc -s aixmibd
stopsrc -s snmpd

chssys -s hostmibd -a "-c public"
chssys -s aixmibd -a "-c public"
chssys -s snmpmibd -a "-c public"

startsrc -s snmpd
startsrc -s aixmibd
startsrc -s snmpmibd
startsrc -s hostmibd

stopsrc -s clinfoES
startsrc -s clinfoES
```
![IMAGE ALT TEXT HERE](./images/Screenshot%20at%202024-06-05%2023-31-49.png)

Watch it in action.\
[![IMAGE ALT TEXT HERE](https://img.youtube.com/vi/x7CUh0MCn38/0.jpg)](https://www.youtube.com/watch?v=x7CUh0MCn38)\

## Buy me a coffee

BTC bc1qd7c9mcvs0dgpd2nv59jsmm2j3qzjhq4a7mramu

ETH 0x7cF556FFA4F3ffD57554D89A19DD92F546598544

LTC LTJwUWPLdDDgK8AYNb419C7UGZgpxuy9qK

DOGE DUBiQaGs4WKJFNc6Adq86QWU3aXgBJR3zW
