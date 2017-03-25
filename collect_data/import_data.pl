#!/usr/bin/perl -w 
use strict;
use warnings;
use IO::Socket::INET;
use String::CRC32;
use lib qw(/home/collect);
use connect_dbi;
use check_threshold_new;

my $dbh=connect_dbi->connect_db() or die "Cannot connect to user database\n";
my $sth=$dbh->prepare("select nodes.name,zapros.param,opros.id from nodes 
	 						join opros on nodes.id=opros.node_id 	
	 						join zapros on opros.zapros_id=zapros.id  
	 						and type=\"nagios\" ")
	 						or die $dbh->errstr();

$sth->execute() or die $sth->errstr();

while(my ($nodename,$zaprosid,$zaprosparam,$oprosid)=$sth->fetchrow_array())
		{my $pluginname="";
			 if($zaprosparam=~m/pluginname=(.*?);/)
			 	{
			 	 	$pluginname=$1;
			 	};

		my $expression="";
			 if($zaprosparam=~m/regexp=(.*?);/)
			 	{
			 		$expression=$1;
			 	};
 		

 my $sock = IO::Socket::INET->new(PeerAddr => $nodename,  
                               	  PeerPort => '*****',  
                                  Proto    => 'tcp');

my $string=chr(0).chr(2).chr(0).chr(1); 

foreach(1..6){$string.=chr(0)}; $string.=$pluginname; 
foreach(length($string)..1035){$string.=chr(0)};

my $crc32=crc32($string);
$crc32=pack("CCCC",$crc32>>24, $crc32>>16&0xff,$crc32>>8&0xff,$crc32&0xff);
$string=substr($string,0,4).$crc32.substr($string,8,1028); 
$sock->send($string); 15. $sock->read($string,1036); 
$string=~s/^.{10}//; $sock->close; my $value;

if($string=~m/$expression/)
 	{$value=$1; print "VALUE=$value\n";
		if(defined($value))
			{
				eval(check_threshold_new::check_threshold($dbh,$oprosid,$value))
			};
	};
	 	};