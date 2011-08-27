#!/usr/bin/perl
use strict;
use warnings;

use English '-no_match_vars';

use constant debug => 0;
my $base_oid = ".1.3.6.1.3.1";
my $iostat_cache = '/tmp/iostat.cache';
my $req;
my %stats;
my $devices;
my $mibtime = time();

# Results from iostat are cached for some seconds so that an
# SNMP walk doesn't result in collecting data over and over again:
my $cache_secs = 60;

# Switch on autoflush
$| = 1;

while (my $cmd = <STDIN>) {
    chomp $cmd;

    if ($cmd eq "PING") {
        print "PONG\n";
    }
    elsif ($cmd eq "get") {
        my $oid_in = <STDIN>;
        chomp $oid_in;
        process();
        getoid($oid_in);
    }
    elsif ($cmd eq "getnext") {
        my $oid_in = <STDIN>;
        chomp $oid_in;
        process();
        my $found = 0;
        my $next = getnextoid($oid_in);
        getoid($next);
    }
    else {
        # Unknown command
    }
}

exit 0;

sub process {

    # We cache the results for $cache_secs seconds
    my $now = time();
    if ($now - $mibtime < $cache_secs) {
        return 'Cached';
    }

    $devices = 1;
    open my $in, '<', $iostat_cache or die "Could not open $iostat_cache : $!\n";

    my $header_seen = 0;

    while (my $line = <$in>) {
        if ($line =~ /^Device/i) {
            $header_seen++;
            next;
        }
        next if ($header_seen < 2);
        next if ($line =~ /^$/);
        
        if ($OSNAME eq 'linux') {
            my @data = split /\s+/, $line;
            $stats{"$base_oid.1.$devices"}  = $devices;
            for my $element (0 .. 11) {
                my $index = $element + 2;
                $stats{"$base_oid.$index.$devices"} = $data[$element];
            }
        }

        if ($OSNAME eq 'solaris') {
           /^([a-z0-9\-\/]+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d)\s+(\d)/;

           $stats{"$base_oid.1.$devices"}  = $devices;     # index
           $stats{"$base_oid.2.$devices"}  = $1;           # device name
           $stats{"$base_oid.3.$devices"}  = $2;           # r/s
           $stats{"$base_oid.4.$devices"}  = $3;           # w/s
           $stats{"$base_oid.5.$devices"}  = $4;           # kr/s
           $stats{"$base_oid.6.$devices"}  = $5;           # kw/s
           $stats{"$base_oid.7.$devices"}  = $6;           # wait
           $stats{"$base_oid.8.$devices"}  = $7;           # actv
           $stats{"$base_oid.9.$devices"}  = $8;           # svc_t
           $stats{"$base_oid.10.$devices"} = $9;           # %w
           $stats{"$base_oid.11.$devices"} = $10;          # %b
        }
        $devices++;
    }
    $mibtime = time;
}

sub getoid {
    my $oid = shift(@_);
    warn "Fetching oid : $oid\n" if (debug);
    if ($oid =~ /^$base_oid\.(\d+)\.(\d+).*/ && exists($stats{$oid})) {
        print $oid. "\n";
        if ($1 == 1) {
            print "integer\n";
        }
        else {
            print "string\n";
        }
        print "$stats{$oid}\n";
    }
    else {
        print "NONE\n";
    }
}

sub getnextoid {
    my $first_oid = shift;
    my $next_oid  = '';
    my $count_id;
    my $index;

    if ($first_oid =~ /$base_oid\.(\d+)\.(\d+).*/) {
        print("getnextoid($first_oid): index: $2, count_id: $1\n") if (debug);
        if ($2 + 1 >= $devices) {
            $count_id = $1 + 1;
            $index    = 1;
        }
        else {
            $index    = $2 + 1;
            $count_id = $1;
        }
        print(
            "getnextoid($first_oid): NEW - index: $index, count_id: $count_id\n"
        ) if (debug);
        $next_oid = "$base_oid.$count_id.$index";
    }
    elsif ($first_oid =~ /$base_oid\.(\d+).*/) {
        $next_oid = "$base_oid.$1.1";
    }
    elsif ($first_oid eq $base_oid) {
        $next_oid = "$base_oid.1.1";
    }
    else {
        $next_oid = "$base_oid.1.1";
    }
    print("getnextoid($first_oid): returning $next_oid\n") if (debug);
    return $next_oid;
}
