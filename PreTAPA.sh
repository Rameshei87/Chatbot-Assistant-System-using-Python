#!/bin/sh
export ORACLE_HOME=/home/oracle/dbase/db_1/
export LD_LIBRARY_PATH=/home/oracle/dbase/db_1/:/home/oracle/dbase/db_1/lib32:/lib:/usr/lib:/usr/local/lib:/home/wbsbatch/PM/FrameworkLib_3.6/OracleLib:/home/wbsbatch/PM/lib/:/home/wbsbatch/PM/bin/:/home/oracle/dbase/db_1/lib32:/home/oracle/dbase/db_1/lib32/stubs/:/home/wbsbatch/PM/bin/

export APP_USER=WBS_CLIENT_PROD/WBS_CLIENT_PROD@CBS;
cd /home/wbsbatch/PM/bin/

./PreTAP WBS_CLIENT_PROD/WBS_CLIENT_PROD@CBS 1 0 1 1 /data2/PM/log/PRETAPA/  PRETAPA Y 12
