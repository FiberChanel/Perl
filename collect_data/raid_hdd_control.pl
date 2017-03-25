#!/usr/bin/perl -w

use strict;
use warnings;
use Net::SNMP;
use home::connect_dbi;
use home::checkbulk qw(checkbulk);


my $alreadyrun=`ps -ef | grep raid| grep -v grep | wc -l`;
print "Already=$alreadyrun\n";
if($alreadyrun>2){exit(0);};


my $dbh=connect_dbi->connect_db() or die "Cannot connect to user database\n";


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
my %nodesvarbinds=();
my %regexps;


my $sth=$dbh->prepare("
 select opros.id,name,opros.value,
ifnull(opros.realporog,porog),
 statemap,opros.state,
 ifnull(opros.realaction,action),
 opros.minvalue,opros.maxvalue,
 defvalue,oprosbind.state-1,zapros.param
 from nodes
 join opros on nodes.id=opros.node_id
 join zapros on zapros.id=opros.zapros_id
 left join opros as oprosbind on opros.realbind=oprosbind.id
 where nodes.flag='NODE'
 and nodes.command='on' and nodes.name regexp \"ser1|der1|op1|tds|furf\"
 and nodes.commandtimestamp<DATE_SUB(NOW(),interval 3 minute)
 and zapros.type=?
 and name not like \"ups%\" 
 and zapros.param not regexp 'baseoid';") or die $dbh->errstr();
$sth->execute('snmpdrive') or die $sth->errstr();


while(my ($oprosid,$nodename,$oldvalue,$porog,$statemap,$oldstate,
$action,$minvalue,$maxvalue,$defvalue,$bindstate,$param)=$sth->fetchrow_array())
{
print "NODE=$nodename";

if($param=~m/slotnumber=(\d+);/){
print "$1\n";
push @{$nodesparams{$nodename}},$1;
}
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
push @{$values{$nodename}},undef;


}

foreach my $hostname(keys %oprosids)
{print "Ready to create session for $hostname SNMP\n";

 my ($session, $error) = Net::SNMP->session(
         -hostname    => $hostname.".m",
         -nonblocking => 0x1,
	 -port	      => 161,
	 -maxmsgsize  => 65000,  
	 -timeout  => 7
	 
      );
          
      if (!defined($session)) {
          printf("ERROR_Session: %s.\n", $error);
     exit 1;
      }
      $session->get_request(
           -varbindlist => [".1.3.6.1.4.1.3582.4.1.4.2.1.1.0"],
           -callback    => [
             \&snmp_answer_cb,$hostname,
          ],
      );


};          
snmp_dispatcher();

sleep(3);
my %pdNumber;
my $slotCount=8;

foreach my $hostname(keys %oprosids)
{print "We have ",$pdNumber{$hostname}," drives in $slotCount slots of $hostname\n";

    foreach(0..$pdNumber{$hostname}-1)
    {push @{$nodesvarbinds{$hostname}},".1.3.6.1.4.1.3582.4.1.4.2.1.2.1.10.".$_;
     push @{$nodesvarbinds{$hostname}},".1.3.6.1.4.1.3582.4.1.4.2.1.2.1.20.".$_;
    }
 my ($session, $error) = Net::SNMP->session(
         -hostname    => $hostname.".m",
         -nonblocking => 0x1,
	 -port	      => 161,
	 -maxmsgsize  => 65000,  
	 -timeout  => 7
      );
          
      if (!defined($session)) {
          printf("ERROR_Session: %s.\n", $error);
     exit 1;
      }
     $session->get_request(
               -varbindlist =>  \@{$nodesvarbinds{$hostname}},
           -callback    => [
             \&snmp_answer_cb
             ,$hostname]
	);

}

my %driveinfo;

snmp_dispatcher();
sleep(3);

foreach my $hostname(keys %oprosids)
{print "HOST $hostname\n";

foreach my $slotindex(0..$slotCount-1)
    {print "$slotindex:";
    my $slotOccuped=0;

my $lsi=`ssh $hostname service lsi_mrdsnmpd status`;
  if($lsi=~m/is\s+(\w+)/ and $1 eq "stopped")
  {$values{$hostname}[$slotindex]=""};
  if($lsi=~m/is\s+(\w+)/ and $1 eq "running")
{

if(defined($nodesparams{$hostname}[$slotindex]) and $nodesparams{$hostname}[$slotindex]==$slotindex){$values{$hostname}[$slotindex]=15};
    
    print "NODES=",${$nodesparams{$hostname}}[$slotindex],"\n";
    foreach my $innerindex(0..$pdNumber{$hostname}-1)
	{if(exists $driveinfo{$hostname}[$innerindex]{"slot"} and $driveinfo{$hostname}[$innerindex]{"slot"}==$slotindex){$slotOccuped=1;print $driveinfo{$hostname}[$innerindex]{"state"};
	$values{$hostname}[$slotindex]=$driveinfo{$hostname}[$innerindex]{"state"}};};
	print "MY__VALUES=",$values{$hostname}[$slotindex],"\n";
	if(!$slotOccuped){print "No DRIVE in slot";};
	print "\n";

}
    }


}

foreach my $hostname(keys %values)
{print $hostname,@{$values{$hostname}},"\n";
}

checkbulk::checkbulk($dbh,\%oprosids,\%values,\%oldvalues,\%porogs,\%statemaps,\%oldstates,\%actions,\%minvalues,\%maxvalues,\%defvalues,\%bindstates);
exit;


sub snmp_answer_cb
{
my $session=shift();
my $hostname=shift();
print "In callback  node=",$session->hostname, "($hostname)\n";
if(!defined($session->var_bind_list))
{print "ERROR:",$session->error,"\n";}
else
{
foreach(sort keys %{$session->var_bind_list})
    {print $_,"===",$session->var_bind_list->{$_},"\n";
    if($_ eq ".1.3.6.1.4.1.3582.4.1.4.2.1.1.0"){$pdNumber{$hostname}=$session->var_bind_list->{$_};};
    if($_=~m/\.1\.3\.6\.1\.4\.1\.3582\.4\.1\.4\.2\.1\.2\.1\.10\.(\d+)$/){$driveinfo{$hostname}[$1]{"state"}=$session->var_bind_list->{$_}};
    if($_=~m/\.1\.3\.6\.1\.4\.1\.3582\.4\.1\.4\.2\.1\.2\.1\.20\.(\d+)$/){$driveinfo{$hostname}[$1]{"slot"}=$session->var_bind_list->{$_}};    }


}

}


