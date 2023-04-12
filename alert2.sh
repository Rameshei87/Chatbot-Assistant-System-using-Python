export ORACLE_HOME=/home/oracle/dbase/db_1
#export LD_LIBRARY_PATH=/home/oracle/dbase/db_1/lib:/home/oracle/dbase/db_1/lib:/home/pngwbs/wbs_5.0.2/BATCH/PM/lib:/home/pngwbs/wbs_5.0.2/BATCH/PM/FrameworkLib_3.6/OracleLib:/usr/lib:/usr/lib64:/home/oracle/dbase/db_1/lib32:/home/oracle/dbase/db_1/lib32/stubs:/home/oracle/dbase/db_1/lib;/usr/bin/perl /usr/share/man/man1/perl.1.gz;/usr/local/lib64/perl5:/usr/local/share/perl5:/usr/lib64/perl5/vendor_perl:/usr/share/perl5/vendor_perl:/usr/lib64/perl5:/usr/share/perl5
export APP_USER=WBS_CLIENT_UAT/WBS_CLIENT_UAT@cbstest;

cd /home/pngwbs/wbs_5.0.2/BATCH/PM/bin
POL=`ps -ef|grep Alerts_Cron1.pl|grep -v "grep" |awk {'print $1'}`
if [ "$POL" != "" ]
then
echo "process is already running"
else
POL=`ls ../signal/ALERT/|grep "alert." |wc|awk '{print $1}'`
if [ "$POL" != 0 ]
then
echo "Remove any Lock or stop file present"
rm -fv ../signal/ALERT/alert.*
fi
perl Alerts_Cron2.pl 88 /home/pngwbs/wbs_5.0.2/BATCH/PM/log/ALERT  LOG ERR &
fi
#perl Alerts_Cron.pl 88 /home/pm_wbs_uat/PM/log/ALERT/ LOG ERR &

