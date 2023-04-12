#!/usr/bin/perl

################################### Starting of Program ##################################
use DBI;
use Mail::Sender;
use MIME::QuotedPrint;
use MIME::Base64;
use DBD::Oracle qw(:ora_types);

#use strict;
# Read Command line parameters passed
# Oracle connection information
#$dbInfo			= "dbi:Oracle:lt29";
$dbserver		= $ARGV[3];
$dbInfo			= "dbi:Oracle:$dbserver";
#$user			= "pm_test";
$user			= $ARGV[1];
#$auth			= "pm_test";
$auth			= $ARGV[2];
$processid		= $ARGV[0];

# Connect to Oracle
$dbHandler = DBI->connect ($dbInfo,$user,$auth,{AutoCommit => 0})
			 or die $DBI::errstr;

print "\n $dbserver \n $user \n $auth \n $processid \n $ARGV[4]";
my $Stmt;
# Get Process Details
$SqlStr="select process_exe_path, lock_file_path from pm_processes where process_id = $ARGV[0]";
$Stmt = $dbHandler->prepare ($SqlStr);
$Stmt->execute ();
my @row = $Stmt	->fetchrow_array();

# Check if the process is already running
$home_path	= $row[0];

#$success_path = "/home/pmgmt/Dev/ALERT/signal/Request_Lock";
$success_path = $row[1];
#$log_path = "/home/pmgmt/Dev/ALERT/log/";
$log_path = $ARGV[4];

if (! -e $log_path)
{
	print "\n Log path $log_path doesn't exist";
	exit;
}	
$LogFileName = GetLogFileName();
open(FH, ">>$log_path$LogFileName");

if (-e $success_path)
{
	print "\nProcess already running \n";
	close(FH);
	exit;
}	
system("touch $success_path");
# Connect to Oracle
#$dbHandler = DBI->connect ($dbInfo,$user,$auth,{AutoCommit => 0})
#			 or die $DBI::errstr;
			 
my ($sStatement);
# Get Requested alerts
$sStatement = $dbHandler->prepare ("select a.alert_id, a.user_name, a.alert_mode, a.alert_address, a.status, a.uniq_ref, b.alert_script, b.alert_desc, b.program_type from PM_ALERTS_ONREQUEST_LOG a, pm_alert_master b where a.alert_id = b.alert_id and a.status='P' and b.alert_status ='A'");

$sStatement->execute ()
			 or print FH $dbHandler->errstr;
# $dbHandler->commit;
#my %calls;
my $alert_id;
my $user_name;
my $alert_mode;
my $alert_address;
my $status;
my $uniq_ref;
my $alert_mode;
my $alert_frequency;
my $alert_script;
my $alert_desc;   
my $program_type;
my $out_param;
my $mail_message;
my $ProcessStartTime;
my $ProcessEndTime;
my $file;
my $totrecs = 0;

#while (my ($alert_id,$user_name,$alert_mode,$alert_address,$status,$alert_script,$alert_desc,$program_type)= $sStatement->fetchrow())
while (my @row = $sStatement	->fetchrow_array()) 
{
	$totrecs = $totrecs +1;
	print $totrecs;
    $alert_id = $row[0];
    $user_name = $row[1];
	$user_name =~s/ /\_/g;
    $alert_mode = $row[2];
    $alert_address = $row[3];
    $status = $row[4];
    $uniq_ref = $row[5];
    $alert_script = $row[6];
    $alert_desc = $row[7];   
    $program_type = $row[8];
    $return_type = "C";
    
   
   $mail_message = "Alert Notification : $alert_desc";
   $file='';
   $file= $home_path.$alert_id."_".$user_name.".txt";
   # If alert program is a shell script   
   if ( $program_type eq "S")
   {
	   if (-e $alert_script) 
           {     # $ret = system "sh $alert_script >> $alert_id$User_name.txt";
           		$hasrows = "Y";
				print FH "\nAlert script $alert_script is a shell script";	              
           		$ProcessStartTime = &GetDateFormat();
           		#print "PST : $ProcessStartTime";
           		$ProcessEndTime = &GetDateFormat();
           		#print "PET : $ProcessEndTime";
                $ret =  `sh $alert_script`;
                if ($ret eq "")
                {
                	print FH "\n No output from the shell script $alert_script";
                	$hasrows = "N";
                	#system("rm $success_path");
                	#next;
            	}	              
                $mail_message = $mail_message."<br/><br/>".$ret;
                $file = "";
            }
       else
       {
		print FH "\nThe file $alert_script does not exist";
		$hasrows = "N";
    	#system("rm $success_path");	
    	#close(FH);	
    	#next;		
       }
   }
   elsif ($program_type eq "P")
   {
		print FH "\nAlert script $alert_script is a stored procedure";	   
	    my $ora_type = '';
	    my $ora_str_value = 5000;
	    
	    $ora_type = '{ ora_type => ORA_RSET }' if ($return_type eq "C");
	    $ora_str_value  = 0 if ($return_type eq "C");
  		#print "Ora Type :".$ora_type." and Value ".$ora_str_value;
	   	my $out_param;
		#$sth = $dbHandler->prepare("BEGIN :out_param := $alert_script (:out_param) ; END;");
		$ProcessStartTime = &GetDateFormat();
		$ProcessEndTime = &GetDateFormat();
		$sth = $dbHandler->prepare("BEGIN $alert_script (?) ; END;");
		# If return type of the procedure is a string		
		if ($ora_type eq "")
		{
			$hasrows = "Y";
			print FH " \n\n Procedure returns a string";
			$sth->bind_param_inout( 1, \$out_param, $ora_str_value);
			$sth->execute || die $dbHandler->errstr;
			if ($out_param eq "")
			{
					print FH " \n\n No Output from the procedure";
					$hasrows = "N";
					#system("rm $success_path");
					#next;
			}	
			$mail_message = $mail_message."<br/>".$out_param;
			print "\nOut Parameter ".$out_param;
			$file= '';
		}
		# If return type of the procedure is a cursor
		if ($ora_type eq "{ ora_type => ORA_RSET }")
		{
			$hasrows = "N";
			print FH " \n\n Procedure returns a cursor";
			$sth->bind_param_inout( 1, \$out_param, 0, { ora_type => ORA_RSET });
			#$sth->bind_param_inout( ":out_param",\$out_param,0, { ora_type => ORA_RSET } );
			@header_rec = @{$sth->{NAME}};
			#print @header_rec;
			open(FILE, ">$file");
			foreach(@header_rec)
			{
					print FILE $_ . " | ";
			}
			 print FILE "\n";

			$sth->execute() || die $dbHandler->errstr;
			
			#open(FILE, ">/home/pmgmt/Dev/ALERT/$alert_desc.txt");
			#open(FILE, ">$home_path $alert_desc.txt");
					
			while(my @arr = $out_param->fetchrow_array())
			{
				$hasrows = "Y";
				print FILE join(" | ", @arr)."\n";	
			}
			close(FILE);
			if ($hasrows eq "N")
			{
				print FH " \n\n Procedure returns no rows";
				#next;
			}	
			
			#$file="/home/pmgmt/Dev/ALERT/$alert_desc.txt";		
			#$file="$home_path $alert_desc.txt";		
		}
	}
   elsif ($program_type eq "Q")
		{
			$hasrows = "N";
			print FH "\nAlert script $alert_script is a SQL query";	   			
			$ProcessStartTime = &GetDateFormat();
			$ProcessEndTime = &GetDateFormat();
			$sth = $dbHandler->prepare($alert_script);
			#print "\n\n$alert_script\n";
			@header_rec = @{$sth->{NAME}};
			#print @header_rec;
			open(FILE, ">$file");
			foreach(@header_rec)
			{
					print FILE $_ . " | ";
			}
			 print FILE "\n";
			
			$sth ->execute;
		
			#open(FILE, ">$home_path $alert_desc.txt");			
			while (my @row = $sth->fetchrow_array()) 
			{
				$hasrows = "Y";
				print FILE join(" | ", @row);	
				print "\n";
			}
			close(FILE);
			if ($hasrows eq "N")
			{
				print FH " \n\n Query returns no rows";
				#next;
			}
			
			#$file="/home/pmgmt/Dev/ALERT/$alert_desc.txt";
			#$file="$home_path $alert_desc.txt";
		}	

	# If alert sending mode is "E-mail"			
	if ($alert_mode eq "E" && $hasrows eq "Y")
	{					
		&Send_Email;
		print FH " \n\n Don't send mail";
	}
    #system("rm $success_path");	
    #close(FH);
}

 if ($sStatement->rows == 0) 
 {
    print FH "\nNo pending requests for alerts found. \n\n";
    #system("rm $success_path");
    #close(FH);
 }
	system("rm $success_path");	
	InsertLogDetails("V");
	close(FH);

 sub Send_Email()
 {
		my @smtpAddress = $dbHandler->selectrow_array("select smtp_server_address, USER_NAME from pm_app_preference where rownum=1");	 
		$mail_server = $smtpAddress[0];
		$from_address = $smtpAddress[1];
		#$mail_server = "192.168.6.1";
		#$from_address = "yogesh@lifetreea.com";

		$subject = "Alert : " || $alert_desc;
		# $file="/home/yogesh/xyz.txt";		
   		$sender = new Mail::Sender  {
             SMTP     => $mail_server,
             from     => $from_address,
             ctype    => "text/html",
             };
             
#{
#      %mail = (
#                SMTP     => $mail_server,
#                from     => $from_address,
#                to       => $alert_address,
#                subject  => $subject
#              );
#}
             
   $Mail::Sender::SITE_HEADERS = "X-Sender: $from_address,$alert_address,$alert_desc";
   #$file = "";
   if ($file eq "")
   {
	    $sender->MailMsg({
            to => $alert_address,
            subject => $subject,
            #headers => "X-Confirm-reading-to:$from_address\nReturn-receipt-to:$from_address\n",
            msg => $mail_message});
	}
	else
	{
   		$sender->MailFile({
            to => $alert_address,
            subject => $subject,
            #headers => "X-Confirm-reading-to:$from_address\nReturn-receipt-to:$from_address\n",
            msg => $mail_message,
            file => "$file"});
	}        
   $sender->Close();
   if($Mail::Sender::error)
   {
       $msg = "$alert_address : $Mail::Sender::error";
      # &insert($acc_id, $billcycle, $to, 'E');
       print "Error : " || $msg;
	&InsertLogDetails("F"); 
	&GetDateFormat($ProcessEndTime);      
   }
   else
   {
       $msg = "\n\n$alert_address : Mail Sent Successfully";
       print FH "\n$msg";
       $ProcessEndTime =&GetDateFormat();
       &InsertLogDetails("S"); 
   }

 }

 sub InsertLogDetails($SentStatus)
{	
	my $SentStatus =shift;
	my ($sStatement);
	# If any output from the alert script
#	if (! $SentStatus eq "V")
#	{
		#print "$alert_id/$alert_address/$user_name/$SentStatus";
		my @UNQ_REF = $dbHandler->selectrow_array("SELECT NVL(MAX(UNIQ_REF),0)+1 FROM PM_ALERT_LOG");
		$SqlStr = "INSERT INTO PM_ALERT_LOG (ALERT_ID, USER_NAME, ALERT_MODE, ALERT_ADDRESS, PROCESS_START_TIME, PROCESS_END_TIME, SENT_STATUS, ACKNOWLEDGED, UNIQ_REF, REQUEST_TYPE) VALUES ('$alert_id','$user_name','$alert_mode','$alert_address',to_date('$ProcessStartTime','dd-mm-yyyy hh24:mi:ss'),to_date('$ProcessEndTime','dd-mm-yyyy hh24:mi:ss'),'$SentStatus','N',@UNQ_REF[0],'A')";
		$sStatement = $dbHandler->prepare ($SqlStr);
		$sStatement->execute () or print FH "\n$dbHandler->errstr";
#	}
	$SqlStr = "UPDATE PM_ALERTS_ONREQUEST_LOG set STATUS = 'S' where UNIQ_REF = '$uniq_ref'";
	#print "\n $SqlStr";
	$sStatement = $dbHandler->prepare ($SqlStr);
	#$sStatement->execute ($alert_id,$user_name,$alert_mode,$alert_address,"to_date($ProcessStartTime,'dd-mm-yyyy hh24:mi:ss')","to_date($ProcessEndTime,'dd-mm-yyyy hh24:mi:ss')",$SentStatus,"N",$i,"A")
	$sStatement->execute () or print FH "\n$dbHandler->errstr";
		
	$dbHandler->commit;
}

sub GetDateFormat()
{	
	my $ProcessTime;
	my($s,$mi,$h,$d,$m,$y,$wdy,$ydy,$isdst) = (localtime);
	$y = $y+1900;
	$m = $m+1;
	$d = '0'.$d if ($d < 10);
	$m = '0'.$m if ($m < 10);
	$h = '0'.$h if ($h < 10);
	$s = '0'.$s if ($s < 10);
	$mi = '0'.$mi if ($mi < 10);
	$ProcessTime= "$d-$m-$y $h:$mi:$s";
	return $ProcessTime;
}

sub GetLogFileName()
{	
	my $LogFileName;
	my($s,$mi,$h,$d,$m,$y,$wdy,$ydy,$isdst) = (localtime);
	$y = $y+1900;
	$m = $m+1;
	$d = '0'.$d if ($d < 10);
	$m = '0'.$m if ($m < 10);
	$h = '0'.$h if ($h < 10);
	$s = '0'.$s if ($s < 10);
	$mi = '0'.$mi if ($mi < 10);
	$LogFileName= "ALERT_REQUEST_$y$m$d";
	return $LogFileName;
}

