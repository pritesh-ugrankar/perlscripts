use strict;
use warnings;
use Config::Tiny;
use Data::Dump;
use IPC::Run3;
use Email::Stuffer;
use Email::Sender::Transport::SMTP ();
use Encode qw/decode/;

#############################################
#Script reads the username, password and 
#email server from a separate config file.
#Please install Config::Tiny like so:
#cpanm Config::Tiny
#Refer to Config::Tiny documentation for
#how to set up the config file.
#############################################
my $array_creds = Config::Tiny->new();
$array_creds   = Config::Tiny->read('vnxe_config.conf');
my $mailserver = $array_creds->{params}->{smtp_server_name};
my $username   = $array_creds->{params}->{username}; 
my $password   = $array_creds->{params}->{pwd_cedar_rapids};
my $vnxe_ip   = $array_creds->{params}->{vnxe_cedar_rapids_ip};

my $aref_cmd1= ['uemcli','-d',$vnxe_ip,'-u',$username,'-p',$password, '/sys/general','show','-detail'];
my $aref_cmd2 = ['uemcli', '-d', $vnxe_ip, '-u', $username, '-p', $password, '/env/bat', 'show', '-detail'];
my $aref_cmd3 = ['uemcli', '-d', $vnxe_ip, '-u', $username, '-p', $password, '/env/ps', 'show', '-detail'];

run3 $aref_cmd1, undef, \my $out1;
run3 $aref_cmd2, undef, \my $out2;
run3 $aref_cmd3, undef, \my $out3;

my $str1 = decode('UTF-16', $out1, Encode::FB_CROAK);
print "$str1\n";

my $batteries = "batteries.txt";
open (my $fh2, '+>', $batteries) or die "Cannot open file.$!";
my $str2 = decode('UTF-16', $out2, Encode::FB_CROAK);
print $fh2 $str2;
close $fh2;

my $power_supply = "power_supply.txt";
open (my $fh3, '+>', $power_supply) or die "Cannot open file.$!";
my $str3 = decode('UTF-16', $out3, Encode::FB_CROAK);
print $fh3 $str3;
close $fh3;

Email::Stuffer
	->text_body($str1)
	->subject("Array Name")
	->attach_file($batteries)
	->attach_file($power_supply)
	->from('array_sn <array_sn@email.com')
	->transport(Email::Sender::Transport::SMTP->new({
				host => $mailserver,
			}))
	->to('DXC Kraft Storage Team <kraftglobalstoragesupport@dxc.com>')
	->send_or_die;
