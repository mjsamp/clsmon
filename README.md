
       
  # Remote PowerHA cluster status monitor
  
  Provides both text stdout and Web.

  Runs on Linux and AIX.
 
 	Based on LiveHA - http://www.powerha.lpar.co.uk
  
 
  Version:  1.0
 
  Author:   Marcos Jean Sampaio - mjsamp@gmail.com


## Requirements

ksh (Korn Shell)

HTTPD Server with cgi support (tested in apache only)

snmpwalk (Linux)

snmpinfo (AIX)

The file hacmp.defs (only AIX)

If it has PowerHA installed you'll find it at 

/usr/es/sbin/cluster/hacmp.defs

or just copy the file from a cluster node.


## HTTP Configurantion example


Create clsmon user

```bash
 useradd -c "CLSMON user" -m clsmon
```

httpd configuration example for Apache 1.x - 2.3

```bash
Alias /clsmon/ /home/clsmon/www/clsmon/
<Directory /home/clsmon/www/clsmon/>
    Options Indexes FollowSymLinks Includes MultiViews
    Order allow,deny
    Allow from all
</Directory>

 #CGI-BIN
ScriptAlias /clsmon-cgi/ /home/clsmon/www/clsmon/clsmon-cgi/
<Directory /home/clsmon/www/clsmon/clsmon-cgi>
    AllowOverride None
    Options ExecCGI Includes FollowSymLinks
    Order allow,deny
    Allow from all
</Directory>
```

## Variables

You should alter some variables in your script to appropriate values according to your environment.

```bash
COMMUNITY="public"
NODES="node1 192.168.1.1"
HACMPDEFS="/hacmp.defs" --> path to hacmp.defs file (needed only in AIX)
CGIFILE="/home/clsmon/www/clsmon/clsmon-cgi/`basename ${0}|cut -d "." -f 1`.cgi" --> path to cgi directory
```

## Run

Put your scripts at clsmon home and execute them.

You can access the web interface at

http://your_web_server/clsmon-cgi/script_name.cgi


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
COMMUNITY public plubic noAuthNoPriv 0.0.0.0 0.0.0.0 -
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
![IMAGE ALT TEXT HERE](https://github.com/mjsamp/clsmon/blob/master/images/Screenshot%20at%202024-05-15%2016-05-38.png)

## Buy me a coffee

BTC bc1qd7c9mcvs0dgpd2nv59jsmm2j3qzjhq4a7mramu

ETH 0x7cF556FFA4F3ffD57554D89A19DD92F546598544

LTC LTJwUWPLdDDgK8AYNb419C7UGZgpxuy9qK

DOGE DUBiQaGs4WKJFNc6Adq86QWU3aXgBJR3zW
