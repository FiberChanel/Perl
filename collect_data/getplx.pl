#!/usr/bin/perl -w
use strict;
use warnings;
use Fcntl;
my $value;
my $val;
my $a;
my $b;
my $c;
my $d;
my $mat;
my $oid0;
my @array;
$ENV{"DISPLAY"}=":0";

sysopen(STDERR ,"/var/log/getplx",O_CREAT|O_TRUNC|O_RDWR);
my $date=`date`;chomp($date);
print STDERR $date," getplx started at ",`hostname`;
print STDERR "Called with ",scalar(@ARGV)," args",join("\t",@ARGV),"\n";
if($ARGV[0] eq "-n"){print STDERR "Get Next\n";print "$ARGV[1].1.1.1\n";};

if($ARGV[0] eq "-g")
{print STDERR "SnmpGet $ARGV[1]\n";



if($ARGV[1]=~m/^\.1\.3\.6\.1\.4\.1\.2021\.60\.0$/)
{print $ARGV[1],"\n";
print "STRING","\n";
print "This id used to get count of PLX\n";
};



#### 60.1 for all nodes except node1


if($ARGV[1]=~m/^\.1\.3\.6\.1\.4\.1\.2021\.60\.1$/) 
{print $ARGV[1],"\n";
 print "STRING","\n";
my $value="";
my $command=`lspci -d :8619| wc -l`;
if ($command=="4") {$value=1};
if ($command=="0") {$value=0};
     print "$value\n";
exit 1;
}

#### 60.3 for node1 (count of PLX)

if($ARGV[1]=~m/^\.1\.3\.6\.1\.4\.1\.2021\.60\.3$/) 
{print $ARGV[1],"\n";
 print "STRING","\n";
my $value="";
my $col;
my $command=`lspci -d :8619| wc -l`;

$value=$command;
     print "$value\n";
exit 1;
}

#### 60.2 for node1 (count of PLC in node1)

if($ARGV[1]=~m/^\.1\.3\.6\.1\.4\.1\.2021\.60\.2$/) 
{print $ARGV[1],"\n";
 print "STRING","\n";
my $value="";
my @array=`lspci -d :8619`;

my $one="05:00.0";
my $a;
my $two="05:00.1";
my $b;
my $three="06:01.0";
my $c;
my $four="06:03.0";
my $d;
my $sum;
if ($array[0]=~m/(\d+\:\d+\.\d+)/ and $1 eq $one){ $a=1;}
if ($array[1]=~m/(\d+\:\d+\.\d+)/ and $1 eq $two){ $b=1;}
if ($array[2]=~m/(\d+\:\d+\.\d+)/ and $1 eq $three){ $c=1;}
if ($array[3]=~m/(\d+\:\d+\.\d+)/ and $1 eq $four){ $d=1;}
$sum=$a+$b+$c+$d;
if ($sum==4){$value=1};
     print "$value\n";
exit 1;
}


}