#!/usr/bin/perl -w
use strict;
use warnings;
use home::connect_dbi;

my $node=$ARGV[0] or die "Usage: powermodule.pl nodename [on|off|reset|reboot]\n";
if($node eq "-h" or $node eq "--help"){die "Usage: powermodule.pl nodename [on|off|reset|reboot]\n";};

my $action=$ARGV[1]||"on";
(my $nodemon=$node)=~s/([a-zA-Z0-9\-]+)(\.{0,1}.*)$/$1\.mon/;
$action=~m/on|off|reset|reboot/i or die "Wrong action: $action";
print "Power $action for $nodemon\n";

(my $nodebmc=$node)=~s/([a-zA-Z0-9\-]+)(\.{0,1}.*)$/$1\.bmc/;


my $dbh=connect_dbi::connect_db() or die "Cannot connect to kvant database\n";
my $sqlcommand="on";
if($action=~m/off/){$sqlcommand="off";}
else {

};
my $sth2=$dbh->do("update nodes set commandtimestamp=NOW(),command=\"$sqlcommand\"
		    where name=\"$node\"") or die $dbh->errstr;

my $sshstatus=1;
if($action=~m/off|reset|reboot/)
{
(my $sshaction=$action)=~s/off/\/sbin\/poweroff/g;
$sshaction=~s/reboot/\/sbin\/reboot/g;
eval{local $SIG{ALRM}=sub{die "alarm clock restart"};
    alarm 3;
    $sshstatus=system("ssh -o ConnectTimeout=1 root\@$nodemon $sshaction");
    alarm 0;
    };
}
if($@ and $@ !~ /alarm clock restart/){warn;};
if(($@ and $@=~m/alarm clock restart/) or ($sshstatus ne 0))
{


(my $bmcpoweraction=$action)=~s/reboot/reset/;

print "ssh $action failed, trying bmc $bmcpoweraction\n";
my $bmcreponse=`ipmitool -I lan -H $nodebmc -p 623 -A md5 -L administrator -U ADMIN -P ADMIN power $bmcpoweraction`;
print $bmcreponse;
}


