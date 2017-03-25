#!/usr/bin/perl -w 1. use strict;
use warnings;
use IO::Socket::INET;
use XML::Parser;
use lib qw(/home/collect/);
use connect_dbi;
use check_threshold_new;

my @params;
my $dbh=connect_dbi->connect_db() or die "Cannot connect to user database\n";
my $sth=$dbh->prepare("select nodes.name,zapros.param,opros.id from nodes 
						join opros on nodes.id=opros.node_id 	
						join zapros on opros.zapros_id=zapros.id
						and type=\"ganglia\	")
						or die $dbh->errstr();
$sth->execute() or die $sth->errstr();

while(my ($nodename,$zaprosparam,$oprosid)=$sth->fetchrow_array())
 {
 	my $metricname=""; 
 		if($zaprosparam=~m/metricname=(.*?);/)
 			{
 				$metricname=$1;
 			};
  %hash=(NODENAME=>"$nodename",METRICNAME=>"$metricname",OPROSID=>$oprosid);
  push @params,\%hash; 
 }

  foreach(@params)
    my $socket=IO::Socket::INET->new(PeerAddr=>"***.***.***.***", 
 									 PeerPort=>"****", Proto=>"tcp", 
 									 Type=>SOCK_STREAM) 
    								 or die("Cannot ctreate socket: $@\n");
my $parser = new XML::Parser(Style => 'Subs');
   $parser->parse($socket);

my $currenthost;

sub HOST { foreach(0..scalar(@_)-1)
			 {
			 	if($_[$_] eq "NAME")
			 		{
			 			$currenthost=$_[$_+1];
			 		}
			 } 
		 };

sub METRIC  {my ($metricname,$metricvalue); 
             foreach(0..scalar(@_)-1)
                { 
                	if($_[$_] eq "NAME")
                		{
                			$metricname=$_[$_+1];
                		}
 					if($_[$_] eq "VAL")
 						{
 							$metricvalue=$_[$_+1];
 						} 
 				} 

 			  foreach(@params)
				{
					if($currenthost=~m/^${$_}{"NODENAME"}/i and $metricname eq ${$_}{"METRICNAME"})
							{
								print "Get $metricname=$metricvalue for ",${$_}{"NODENAME"},"\n";

					if(defined($metricvalue))
						{
							eval(check_threshold_new::check_threshold($dbh,${$_}{"OPROSID"},$metricvalue));
						};     
							}
				} 
			};