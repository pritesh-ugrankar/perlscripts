use strict;
use warnings;
use Email::Stuffer;
use Email::Sender::Transport::SMTP ();
use Config::Tiny;
use Cwd;

#############################################
#Script reads the username, password and 
#email server from a separate config file.
#Please install Config::Tiny like so:
#cpanm Config::Tiny
#Refer to Config::Tiny documentation for
#how to set up the config file.
#############################################
my $array_creds = Config::Tiny->new();
$array_creds    = Config::Tiny->read('G:\clar_0035\clar_config.conf');
my $array_ip    = $array_creds->{params}->{clar35_ip};
my $username    = $array_creds->{params}->{username}; 
my $password    = $array_creds->{params}->{password};
my $mailserver  = $array_creds->{params}->{smtp_server_name};

my $array_info = "array_info.txt";
open (my $fh_array_info, '>', $array_info) or die "Cannot open file.$!"; 
my $cmd_array_info = `naviseccli -h $array_ip -User $username -Password $password -scope 0 getagent`;
print $fh_array_info $cmd_array_info;
{
	local $/ = "\n\n";
	chomp($cmd_array_info);
}

my $array_health = `naviseccli -h $array_ip -User $username -Password $password -scope 0 faults -list`;
chomp($array_health);
my $array_crus = "array_crus.txt";
open (my $fh_array_crus, '>', $array_crus) or die "Cannot open file.$!";
my $cmd_array_crus = `naviseccli -h $array_ip -User $username -Password $password -scope 0 getcrus`;
print $fh_array_crus $cmd_array_crus;

my $array_disks = "array_disks.txt";
open (my $fh_array_disks, '>', $array_disks) or die "Cannot open file.$!";
my $cmd_array_disks = `naviseccli -h $array_ip -User $username -Password $password -scope 0 getdisk`;
print $fh_array_disks $cmd_array_disks;

my $array_getcache = "array_cache.txt";
open (my $fh_array_getcache, '>', $array_getcache) or die "Cannot open file.$!";
my $cmd_array_getcache = `naviseccli -h $array_ip -User $username -Password $password -scope 0 getcache`;
print $fh_array_getcache $cmd_array_getcache;

my $array_getsp = "array_storage_processors.txt";
open (my $fh_array_getsp, '>', $array_getsp) or die "Cannot open file.$!";
my $cmd_array_getsp = `naviseccli -h $array_ip -User $username -Password $password -scope 0 getsp`;
print $fh_array_getsp $cmd_array_getsp;

my $array_getrg = "array_raid_group.txt";
open(my $fh_array_getrg, '>', $array_getrg) or die "Cannot open file.$!"; 
my $cmd_array_getrg = `naviseccli -h $array_ip -User $username -Password $password -scope 0 getrg`;
print $fh_array_getrg $cmd_array_getrg;

#Clariion Capacity calculations start here.
my $raid_group_id;
my $raid_group_type;
my $raw_cap_blocks;
my $logical_cap_blocks;
my $free_non_contiguous_cap_blocks;
my $free_contiguous_cap_blocks;
my $total_raw_cap_blocks;
my $total_logi_cap_blocks;
my $total_used_cap_blocks;
my $total_contiguous_cap_blocks;
my $total_non_contiguous_cap_blocks;
my $detailed_capacity = "capacity.txt";
my $fh_detailed_capacity;
open $fh_array_getrg, "<", $array_getrg or die "Cannot open file.$!";
{
	open my $fh_detailed_capacity, ">", $detailed_capacity or die "Cannot open file.$!";
	local $/ = "\n\n";
while (my @records = <$fh_array_getrg>){

	foreach my $line(@records){

		if ($line =~/RaidGroup ID:\s+([0-9]+)/) {
			$raid_group_id = $1;
		}
	
		if ($line =~/RaidGroup Type:\s+(.*)/) {
			$raid_group_type = $1;
		}
	
		if ($line =~/Raw.*:\s+([0-9]+)/) {
			$raw_cap_blocks = $1;
		}
	
		if ($line =~/Logical.*:\s+([0-9]+)/) {
			$logical_cap_blocks = $1;
		}
	
		if ($line =~/Free Cap.*non-conti.*:\s+([0-9]+)/) {
			$free_non_contiguous_cap_blocks = $1;
		}
	
		if ($line =~/Free.*unbound.*:\s+([0-9]+)/) {
			$free_contiguous_cap_blocks = $1;
		}

		printf $fh_detailed_capacity "RAID GROUP ID: $raid_group_id [RAID Type: $raid_group_type]\n";
		printf $fh_detailed_capacity "Raw Capacity                                  : %0.2f (GB)\n",
		$raw_cap_blocks/2/1024/1024;
		printf $fh_detailed_capacity "Logical Capacity                              : %0.2f (GB)\n", 
		$logical_cap_blocks/2/1024/1024;
		printf $fh_detailed_capacity "Total Used Capacity                           : %0.2f (GB)\n",
		($logical_cap_blocks - $free_non_contiguous_cap_blocks)/2/1024/1024; 
		printf $fh_detailed_capacity "Free (Usable) Capacity (Non contiguous Space) : %0.2f (GB)\n",
		$free_non_contiguous_cap_blocks/2/1024/1024; 
		printf $fh_detailed_capacity "Free (Usable) Capacity (Contiguous Space)     : %0.2f (GB)\n",
		$free_contiguous_cap_blocks/2/1024/1024; 
		printf $fh_detailed_capacity "----------------------------------------------------------\n"; 

		$total_raw_cap_blocks += $raw_cap_blocks;
		$total_logi_cap_blocks += $logical_cap_blocks;
		$total_used_cap_blocks += ($logical_cap_blocks - $free_non_contiguous_cap_blocks);
		$total_non_contiguous_cap_blocks += $free_non_contiguous_cap_blocks;
		$total_contiguous_cap_blocks += $free_contiguous_cap_blocks;
	}
   }

}
my $total_raw_cap_gb = sprintf("%2.2f", $total_raw_cap_blocks/2/1024/1024);
my $total_logical_cap_gb = sprintf("%2.2f", $total_logi_cap_blocks/2/1024/1024);
my $total_non_contiguous_cap_gb = sprintf("%2.2f", $total_non_contiguous_cap_blocks/2/1024/1024);
my $total_contiguous_cap_gb = sprintf("%2.2f", $total_contiguous_cap_blocks/2/1024/1024);
#my $total_used_cap_gb = sprintf("%2.2f", $total_logical_cap_gb - $total_contiguous_cap_gb);
my $total_used_cap_gb = sprintf("%2.2f", $total_used_cap_blocks/2/1024/1024);
my $array_model;
my $array_sn;
my $email_subject;
open ($fh_array_info, '<', $array_info) or die "Cannot open file.$!";

while (my $line = <$fh_array_info>) {
	if ($line =~/^Model:\s+(.*)/) {
		$array_model = $1;
	}

	if ($line =~/^Serial No:\s+(.*)/) {
		$array_sn = $1;
	}
}
$email_subject = "$array_model $array_sn Health Check & Capacity";
my $script_path = Cwd::abs_path($0);
my $hostname = `hostname`;
chomp ($hostname);
my $email_body =<<EMAIL_BODY;
------------------------------------------------------------------------------------------
This is an automated email generated by $0
------------------------------------------------------------------------------------------
Script Path: $script_path
------------------------------------------------------------------------------------------
Hostname: $hostname 
------------------------------------------------------------------------------------------
$cmd_array_info
------------------------------------------------------------------------------------------
Array health status: $array_health

Please check the attached files if health status is not healthy.
------------------------------------------------------------------------------------------
Overall Array Capacity (Please check the capacity.txt file without fail)
------------------------------------------------------------------------------------------
Overall Array Capacity (Please check the capacity.txt file for details)
Total raw capacity                            : $total_raw_cap_gb (GB)
Total logical capacity                        : $total_logical_cap_gb (GB)
Total used capacity 	                      : $total_used_cap_gb (GB)  
Total non contiguous Capacity 		      : $total_non_contiguous_cap_gb (GB)
Total contiguous Capacity (Actual Usable)     : $total_contiguous_cap_gb (GB)
EMAIL_BODY
Email::Stuffer
	->subject($email_subject)
	->text_body($email_body)
	->attach_file($array_info)
	->attach_file($array_crus)
	->attach_file($array_disks)
	->attach_file($array_getcache)
	->attach_file($array_getsp)
	->attach_file($array_getrg)
	->attach_file($detailed_capacity)
	->from('Array Sn <array_name_sn@email.com>')
	->transport(Email::Sender::Transport::SMTP->new({
				host => $mailserver,
			}))
	->to('teamdl <teamdl@email.com>')
	->send_or_die;
