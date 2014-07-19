#!/usr/bin/perl
#===============================================================================
#
#         FILE:  check_backuppc_hosts.pl
#
#        USAGE:  ./check_backuppc_hosts -p path_to_BackupPC_serverMesg -h
#					-p : set path of BackupPC_serverMesg binary file (default is /usr/share/backuppc/bin/BackupPC_serverMesg)
#					-h : specify a hostname from backuppc to check (if unset, all hosts will be checked)
#
#  DESCRIPTION:  Nagios plugins to check backups from BackupPC software
#
#      OPTIONS:  -p, -b, -h
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#      LICENSE:  This Nagios module is under GPLv2 License
#       AUTHOR:  Pierre Mavro (), pierre@mavro.fr
#      COMPANY:  
#      VERSION:  0.3
#      CREATED:  04/04/2009
#===============================================================================
#
# Installation (nagios client side) :
# - Copy the script in your nagios plugins directory (usualy /usr/lib/nagios/plugins)
# - Set good rights (700 for nagios user)
# - Add those two lines in your suoders file :
#   - Cmnd_Alias  GETHOSTS = /usr/share/backuppc/bin/BackupPC_serverMesg (or replace by your $bppccmd value bellow)
#   - nagios  ALL=(backuppc) NOPASSWD: GETHOSTS
#
#===============================================================================
#
# History :
#
# v0.3 :
# + Adding possibility to check only one host with -b
# = Improved help menu and options
# = Improved returned messages to nagios
#
# v0.2 :
# + Added number of backuped hosts in status information column
# + Added number of hosts errors in status information column
# + Added an unknow host detection (from host backuppc file)
# = Check hosts method optimized ((x hosts) * (time to check) faster)
# = Improved security on sudoers command
#
# v0.1 :
# + First version
#
#===============================================================================

use strict;
use Getopt::Long;

my $bppccmd='/usr/share/backuppc/bin/BackupPC_serverMesg';

# Get list of all backuped hosts
sub format_input
{
	my $hostname = shift;
	my ($bppc_check_cmd, @formated_bppccmd);
	
    # Test $bppccmd execution
    unless (-x $bppccmd)
    {
    	print "Could not execute $bppccmd file : $!";
    	exit 3;
    }
    
    # Only bakcuppc user could check backup state
    if ($hostname ne 'all')
    {
    	# Check only one host
    	$bppc_check_cmd = "/usr/bin/sudo -u backuppc $bppccmd 'status host($hostname)'";
    }
    else
    {
    	# Check all hosts
    	$bppc_check_cmd = "/usr/bin/sudo -u backuppc $bppccmd 'status hosts'";
    }

    open (COMMANDBACKUPPC, "$bppc_check_cmd |") or die "Couldn't execute $bppc_check_cmd : $!\n";
    while (<COMMANDBACKUPPC>)
    {
        @formated_bppccmd = split(/},/), $_;
    }
    close (COMMANDBACKUPPC);

    return (\@formated_bppccmd);
}

# Check backup status for each hosts and send to nagios
sub check_hosts_status
{
	my $hostname=shift;
	my (@hosts_list, @errors);
	
    my $formated_bppccmd_ref = &format_input($hostname);
    my @formated_bppccmd = @$formated_bppccmd_ref;
    
  	if ($hostname eq 'all')
  	{
	   	foreach (@formated_bppccmd)
	   	{
       		chomp $_;
	       	my $current_host;
	        # Add host to hosts_list
       		if (/"(\S+)" => {/)
       		{
	        	push @hosts_list, $1;
           		$current_host=$1;
		        # Verify if any errors has occcured during backup
            	if (/"error" => "(.+?)"/i)
	            {
	               	push @errors, "$current_host : $1";
            	}
       		}
   		}
    }
    else
    {
    	foreach (@formated_bppccmd)
    	{
        	chomp $_;
        	my $current_host=$hostname;
        		if ($_ !~ /^Got reply: ok$/)
        		{
	        		push @hosts_list, $hostname;
            		
		            # Verify if any errors has occcured during backup
	            	if (/"error" => "(.+?)"/i)
	            	{
	                	push @errors, "$current_host : $1";
            		}
        		}
        		else
        		{
					print "Hostname $current_host doesn't exist, can't check\n";
					exit 3;
        		}
    	}
    }
    
	# Give result to Nagios
    my $total_errors = @errors;
    if ($total_errors ne 0)
    {
        my $many='';
        $many='s' if ($total_errors > '1');
        my @formated_errors = join " - ", @errors;
        print "[$total_errors problem" . "$many" . "] - @formated_errors\n";
        exit(2);
    }
    else
    {
        my $total_hosts = @hosts_list;
        unless ($total_hosts == 0)
        {
        	print "All ($total_hosts) servers have been correctly backuped\n";
        	exit(0);
        }
        else
        {
        	print "No hostname to check have been found\n";
        	exit 3;
        }
        
    }
}

sub check_opts
{
	# Vars
	my $hostname = 'all';
	my $bin_path;
	
	# Set options
	GetOptions( "help|h"    => \&help,
				"b=s"       => \$hostname,
				"p=s"		=> \$bin_path);

	&check_hosts_status($hostname);
}

sub help
{
	print "Usage : check_backuppc_hosts [path_to_BackupPC_serverMesg]\n";
	print "\t-p : set path of BackupPC_serverMesg binary file (default is /usr/share/backuppc/bin/BackupPC_serverMesg)\n";
	print "\t-b : specify a hostname from backuppc to check (if unset, all hosts will be checked)\n";
	print "\t-h : print this message\n";
    exit(-1);
}

&check_opts;
