#!/usr/bin/perl -w

use strict;
use warnings;
use Net::Telnet;

sub decode_status($);
sub decode_regime($);
sub decode_vdisk_status($);

use home::connect_dbi;
use home::checkbulk qw(checkbulk);

my $alreadyrun=`ps -ef | grep dothill.pl| grep -v grep | wc -l`;
print "Already=$alreadyrun\n";
if($alreadyrun>2){exit(0);};


my $dbh=connect_dbi->connect_db() or die "Cannot connect to kvant database\n";


my %oprosids;
my %values;
my %oldvalues;
my %porogs;
my %statemaps;
my %oldstates;
my %actions;
my %minvalues;
my %maxvalues;
my %defvalues;
my %bindstates;
my %factors;
my %nodesparams;
my %commands;
my %regexps;

#
my %zapross;
#

my $sth=$dbh->prepare("
 select name,zapros.param,command(param),opros.id,opros.value,
ifnull(opros.realporog,porog),
 statemap,opros.state,
 ifnull(opros.realaction,action),
 opros.minvalue,opros.maxvalue,
 defvalue,oprosbind.state-1
 from nodes
 join opros on nodes.id=opros.node_id
 join zapros on zapros.id=opros.zapros_id
 left join opros as oprosbind on opros.realbind=oprosbind.id
 where nodes.flag='NODE'
 and zapros.type=?
 and name regexp \"raid\";") or die $dbh->errstr();
$sth->execute('telnet') or die $sth->errstr();

while(my ($nodename,$param,$command,$oprosid,$oldvalue,$porog,$statemap,$oldstate,
$action,$minvalue,$maxvalue,$defvalue,$bindstate)=$sth->fetchrow_array())
{
print "OPROSID=",$oprosid," NODE=",$nodename," POR=",$porog," STATEMAP=",$statemap," OLDSTATE=",$oldstate,
"MIN=",$minvalue," MAX=",$maxvalue," DEF=",$defvalue,"\n";
push @{$nodesparams{$nodename}},$param;

if($param=~m/command=(.*?);/)
#{push @{$commands{$nodename}},$command;}
{ ${$commands{$nodename}}{$command}=undef;}
else{push @{$commands{$nodename}},undef;}
if($param=~m/regexp=(.*?);/)
{push @{$regexps{$nodename}},$1;print "RE=$1\n";}
else{push @{$regexps{$nodename}},undef;}

#
if($param=~m/zaprosname=(.*?);/)
{push @{$zapross{$nodename}},$1;print "RE_ZAPR=$1\n";}
else{push @{$zapross{$nodename}},undef;}
#

push @{$oprosids{$nodename}},$oprosid;
push @{$oldvalues{$nodename}},$oldvalue;
push @{$porogs{$nodename}},$porog;
push @{$statemaps{$nodename}},$statemap;
push @{$oldstates{$nodename}},$oldstate;
push @{$actions{$nodename}},$action;
push @{$minvalues{$nodename}},$minvalue;
push @{$maxvalues{$nodename}},$maxvalue;
push @{$defvalues{$nodename}},$defvalue;
push @{$bindstates{$nodename}},$bindstate;
push @{$factors{$nodename}},1;
push @{$values{$nodename}},undef;
}

my %sessions;
foreach my $controller(keys %oprosids)
{my $controllerhostname=$controller.".m";
#Begin to konnect to raid controllers
$sessions{$controller}=new Net::Telnet (Errmode=>"return", Input_Log=>"$controller");
$sessions{$controller}->open($controllerhostname);
$sessions{$controller}->waitfor('/login:.*$/');
sleep(2);
my $retcode=$sessions{$controller}->print("***********");
$sessions{$controller}->waitfor('/Password:.*$/');
$retcode=$sessions{$controller}->print("*************");
sleep(6);
foreach(0..4){
my $line=$sessions{$controller}->getline();
print "\nGET LINE = $line\n";
if($line=~m/Server Power: On/
or $line=~m/NN StorageWorks Gdsfc/i
or $line=~m/R\/Evo 1234-N/i
or $line=~m/R\/Evolution DHmodel/i
){last;};
}
$sessions{$controller}->waitfor('/#/');

foreach my $command(keys %{$commands{$controller}})
{print "$controller: running $command\n";

@{$commands{$controller}{$command}}=$sessions{$controller}->cmd("$command");
print "GET=",@{$commands{$controller}{$command}},"\n";

foreach my $currentline(@{$commands{$controller}{$command}})
{foreach my $oprosidindex(0..$#{$oprosids{$controller}})
{
if(defined(${$regexps{$controller}}[$oprosidindex]) and $currentline ne "" and $currentline ne "\n" and $currentline=~m/${$regexps{$controller}}[$oprosidindex]/)
    {
     print "Match ZAPROS $1 $currentline against ${$zapross{$controller}}[$oprosidindex]\n";
    my $value=$1;
    if(${$regexps{$controller}}[$oprosidindex]=~m/Status/i){$value=decode_status ($value);};
    if(${$zapross{$controller}}[$oprosidindex]=~m/Режим.* логического.* диск.*/){$value=decode_regime ($value);};

    if(${$zapross{$controller}}[$oprosidindex]=~m/татус логического.* диск.*/i){$value=decode_vdisk_status ($value);};
    
        print "VALUE=$value\n";
    ${$values{$controller}}[$oprosidindex]=$value;
    
    }

}
}

}

$sessions{$controller}->close();

}


checkbulk::checkbulk($dbh,\%oprosids,\%values,\%oldvalues,\%porogs,\%statemaps,\%oldstates,\%actions,\%minvalues,\%maxvalues,\%defvalues,\%bindstates);


sub decode_status($)
{my $value=shift();
if($value=~m/OK/){return 1;};
if($value=~m/Warning/){return 2;};
if($value=~m/Failed/){return 3;};
return 0;
}

sub decode_regime($)
{my $value=shift();
if($value=~m/RAID0/){return 0;};
if($value=~m/RAID1/){return 1;};
if($value=~m/RAID5/){return 5;};
if($value=~m/RAID6/){return 6;};
return 0;
}

sub decode_vdisk_status($)
{my $value=shift();
if($value=~m/FTOL/){return 1;};
if($value=~m/UP/){return 2;};
if($value=~m/FTDN/){return 3;};
if($value=~m/OFFL/){return 4;};
if($value=~m/CRIT/){return 5;};
if($value=~m/QRCR/){return 6;};
if($value=~m/QROF/){return 7;};
return 0;
}





