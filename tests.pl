#!/usr/bin/perl
#
# Tests for processmail.pl

use strict;
use warnings;

use Data::Dumper;

my $logfile = '/var/tmp/thismail.txt';

my @actions = ('ack','clear','disable','enable', 'garbage');
my @hosts = ('lpmonitor1');
my @services = ('AVG_Load','SITE_Line','SSH','SSH_Cluster','WEB_80');
my @alerts = ();
my @result_set = ();
my %result = ();

my $mail_from = 'admin@company.com';
my $rcpt_to = "user";
my $body = "Anything goes here.";

foreach my $host (@hosts) {
        my $host_alert = " Re: ** Host CRITICAL alert for " . $host . "\! **";
        foreach (@actions) {
                my $alert = $_ . $host_alert;
                push(@alerts,$alert);
        }
        foreach (@services) {
                my $service_alert = " Re: ** CRITICAL alert - " . $host . '/' . $_ . " is CRITICAL **";
                foreach (@actions) {
                        my $alert = $_ . $service_alert;
                        push(@alerts,$alert);
                }
        }
}

sub send_mail {
        my $sendmail = "/usr/sbin/sendmail -t";
        my ($mail_from, $rcpt_to, $subject, $body) = @_;

        open(SENDMAIL, "|$sendmail") || die("SENDMAIL ERROR: $!\n");
        print SENDMAIL ("From: $mail_from\n");
        print SENDMAIL ("To: $rcpt_to\n");
        print SENDMAIL ("Subject: $subject\n\n");
        print SENDMAIL ("$body\n");
        close(SENDMAIL);
}

sub search_log {
        my $entry = shift;

        my $string = quotemeta $entry;
        my $slurp;
        {
                local $/ = undef;
                open my $textfile, '<', $logfile || die "Cannot open $logfile: $!\n";
                $slurp = <$textfile>;
                close $textfile;
        }

        return ($slurp =~ /$string/) ? "PASS" : "FAIL";
}

print "Testing... [";
foreach (@alerts) {
        $result{'timestamp'} = time();
        $result{'subject'} = $_;
        push(@result_set, {%result});
        %result = ();
        send_mail ($mail_from, $rcpt_to, $_, $body);
        sleep 2;
        print "=";
}
print "] DONE\!\n\n";

for my $i ( 0 .. $#result_set ) {
        my $timestamp = $result_set[$i]{'timestamp'};
        printf "%4d : [%-10d] : %-75s ---> %s\n", $i+1, $timestamp, $result_set[$i]{'subject'}, search_log($timestamp);
}
print "\n";
