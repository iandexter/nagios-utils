#!/usr/bin/perl
#
# Pushes incoming acknowledgement mails to Nagios. Derived from
#
#       http://www.techopsguys.com/2010/01/05/acknowledge-nagios-alerts-via-email-replies/
#
# Uses procmail recipe to accept mails from whitelisted senders only.
#
# There are two possible notifications -- for host or service alerts -- for which several
# actions can be performed: 'ack', 'clear', 'enable', 'disable'. To send an external
# command on an alert, reply using any of the following subject lines:
#
#       action Re: ** Host $HOSTSTATE$ alert for $HOSTNAME$! **
#       action Re: ** $NOTIFICATIONTYPE$ alert - $HOSTNAME$/$SERVICEDESC$ is $SERVICESTATE$ **

use strict;
use warnings;

use Data::Dumper;
use Switch;

my $debug = 0;

my ($subject, $sender, $action);
my ($foo, $bar);

my ($host, $service);
my %command = (
        'ack' => "ACKNOWLEDGE",
        'clear' => "REMOVE",
        'enable' => "ENABLE",
        'disable' => "DISABLE",
);
my $extcmd;
my $commandfile = "/usr/local/nagios/var/rw/nagios.cmd";

my $now = time();

### Get Subject: and From: from STDIN and fudge with them
while(<>) {
        chomp($_);
        if (/From/) {
                s/(From:\s)//gi;
                s/([a-z]+|[a-z0-9]+)(\..*@.*|@.*)/$1/;
                $sender = $_;
        } else {
                s/(Subject:\s)//gi;
                s/(Re:\s|Fw:\s|\!|-|\*)//gi;
                s/\s+/\ /g;
                $subject = $_;
        }
}

### Whip up something that Nagios can use
if ($subject =~ /Host/ ){
        ($action, undef, undef, undef, undef, $host) = split / /,$subject;
} else {
        ($foo, $bar) = split(/\//, $subject);
        ($action, undef, undef, $host) = split(/\ /, $foo);
        ($service) = $bar =~ /^(.*) is.*$/;
}
$action = lc($action);

### Test if action makes sense
if (! exists $command{$action}) { exit 1; }

### Form the external command
$extcmd = "[$now] " . $command{$action};
$extcmd .= ($service) ? "_SVC_" : "_HOST_";
switch ($action) {
        case "ack" { $extcmd .= "PROBLEM;"; }
        case "clear" { $extcmd .= "ACKNOWLEDGEMENT;"; }
        case /able/ { $extcmd .= "NOTIFICATIONS;"; }
}
$extcmd .= ($service) ? "$host;$service" : "$host";
if ($action =~ /ack/) { $extcmd .= ";1;1;1;$sender;Acknowledged through email - $now"; }
$extcmd .= "\n";

### Debug - Don't actually do anything.
if ($debug) {
        print $extcmd;
        exit 1;
}

### Inject to Nagios
open(CMDFILE, ">$commandfile") || die "Cannot open $commandfile: $!\n";
print CMDFILE $extcmd;
close CMDFILE;
exit 0;
