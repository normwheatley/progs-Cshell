#!/bin/bash
# Name:       scan_logs.sh
# Purpose:    To scan facs.log, syslog and facs_cl.log files for errors
# Author:     Norm Wheatley (C) vigilent 2014/10/6
#
DESCRIPTION="
This uses grep to scan the facs.log, syslog and facs_cl.log files for errors. It can scan many such files and will uncompress gzipped files 
It takes 4 optional parameters:
 -m the month in format Mmm
 -d day in format xy (integers, y is optional)
 -f number of facs.log files to scan 
 -s number of syslog/facs_cl.log files to scan
This should be run in the directory where the logs are under sudo as you may have to unzip any gunzipped files

Examples:
 `basename $0` ... just look at facs.log, syslog and facs_cl.log
 `basename $0` -m Sep -d 11 -f 2 -s 7 ... scans 2 facs.logs and 7 syslog and facs_cl.log files for errors etc that occurred on Sep 11
"
#
# check arguments
nflogs=1
nslogs=1
while getopts ":m:d:f:s:h" Option
do
  case $Option in
    h ) echo " $DESCRIPTION";exit 0;; 
    m ) mon="$OPTARG";;
    d ) day="$OPTARG";; 
    f ) nflogs="$OPTARG";;
    s ) nslogs="$OPTARG";; 
    * ) echo "Unimplemented option chosen.";exit 0;;   # Default.
  esac
done
#
# check that the user is using sudo (root)
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi
#
#  define the function to get the log file names
function get_logfile() {
   if [ $2 -eq 0 ]
   then
    logfile=$1
   else
    logfile=$1.${2}
   fi
# now make sure the log file (or its gzipped version) exists - exit if not return with error
  if [ ! -f ${logfile} ]
   then
   if [ -f ${logfile}.gz ]
   then
     echo "unzipping ${logfile}.gz"
      gunzip ${logfile}.gz
    else
       echo "No such file as ${logfile} or ${logfile}.gz..... quitting!"
       return 2
    fi
  fi
  return 0   # end function get_logfile
}
#
# create the date search strings
if [ ${mon} ]
then
  if [ ${day} ] 
  then 
    date1=${mon}" "${day}
    date2=${mon}"  "${day}
    date_search="with date string ${date1} and ${date2}"
    echo "Searching last ${nflogs} facs.logs and last ${nslogs} syslogs/facs_cl.logs ${date_search}"
  else
    date1=${mon}" "      
    date2=${mon}" "
    date_search="with date string ${date1}"
    echo "Searching last ${nflogs} facs.logs and last ${nslogs} syslogs/facs_cl.logs ${date_search}" 
  fi
else
  date1=" "
  date2=" "
  date_search=""
  echo "Searching last ${nflogs} facs.logs and last ${nslogs} syslogs/facs_cl.logs ${date_search}"
fi
#
# first switch to the log directory
echo "first switch to the log directory (/var/log)"
cd /var/log
#
# loop through each facs.log file
for (( x=0; x<${nflogs}; x++ ))
do
#
# first make sure the facs.log file (or its gzipped version) exists - exit if not
  get_logfile facs.log ${x}
  ret=$?
  if [ ${ret} -eq 0 ] 
  then
    echo "Got good file ${logfile} ... carrying on"
    echo "============================================== CHECKING IN ${logfile} NEXT ================================================================="
    echo "============================================ MAKING ${logfile}.tmp file ${date_search} ========================="
    awk  -v search="${date1}|${date2}" '$0 ~ search' ${logfile} > ${logfile}.tmp
    echo "============================================ GREPPING FOR error, warn, abort, trace, dump, shutdown, bogus, restart, regen, fail ======================================"
    cat ${logfile}.tmp | grep -i -e error -e warn -e abort -e trace -e dump -e shutdown -e bogus -e fail -e regen -e restart | grep -v -e Error= -e timeout -e "closed by the peer" -e "reset by peer" -e "onnection refused" -e "Abort probing" -e "oncern" -e "id authen" -e "-- backtrace --" -e "OID(0)" -e FanDesign 
    echo "========================================== GREP ${logfile}.tmp FOR facs_cl =========================================="
    grep -e "facs_cl " ${logfile}.tmp
    echo "========================================== GREP ${logfile}.tmp FOR sweep =============================================="
    grep sweep ${logfile}.tmp | grep complete
    echo "========================================== GREP ${logfile}.tmp FOR errno, sql ==========================================="
    grep -i -e errno -e sql ${logfile}.tmp
    echo "========================================== GREP ${logfile}.tmp FOR AS OVER 5000 ========================================="
    echo "              Date                          ATspread"
    grep -i AS= ${logfile}.tmp | grep -v Concern | awk -F"AS=" '{print $0, $NF}' | awk '{if ($NF>5000) print $1, $3, $4, $5, $6, $7,$NF}'
  fi
done
#
# loop through each syslog file
for (( x=0; x<${nslogs}; x++ ))
do
#
# now make sure the facs.log file (or its gzipped version) exists - exit if not
  get_logfile syslog ${x}
  ret=$?
  if [ ${ret} -eq 0 ]
  then
    echo "Got good file ${logfile} ... carrying on"
    echo "============================================== CHECKING IN ${logfile} NEXT ================================================================="
    echo "============================================ MAKING ${logfile}.tmp file ${date_search} ========================="
    awk  -v search="${date1}|${date2}" '$0 ~ search' ${logfile} > ${logfile}.tmp
    echo "========================================== GREP ${logfile}.tmp FOR high CPU load ====================================="
    grep -i "top -" syslog | awk '{if (($15+$16+$17/3) > 3) print "high load average ... " ($15+$16+$17)/3}'
    echo "========================================== GREP ${logfile}.tmp FOR abort, error, warn ===================================="
    grep -i -e abort -e error -i -e warn ${logfile}.tmp | grep -v frequency
    echo "========================================== GREP ${logfile}.tmp FOR errno, sql ========================================="
    grep -i -e errno -e sql ${logfile}.tmp
    echo "========================================== GREP ${logfile}.tmp FOR power ================================================"
    grep -i power ${logfile}.tmp
  fi
done
#
# Go down to the facs_cl log directory
echo "switch to the  facs_cl log directory (/var/log/vems/learn)"
cd /var/log/vems/learn
#
# loop through each facs_cl.log file
for (( x=0; x<${nslogs}; x++ ))
do
#
# now make sure the facs_cl.log file (or its gzipped version) exists - exit if not
  get_logfile facs_cl.log ${x}
  ret=$?
  if [ ${ret} -eq 0 ]
  then
    echo "Got good file ${logfile} ... carrying on"
    echo "============================================== CHECKING IN ${logfile} NEXT ============================================================="
    echo "========================================== GREP ${logfile} FOR sql, abort, error, warn ===================================="
    grep -i -e sql -e abort -e error -i -e warn ${logfile}
  fi
done
