#!/usr/bin/perl
use strict;

use Fcntl 'LOCK_EX', 'LOCK_NB';

unless (flock DATA, LOCK_EX | LOCK_NB) {
    die "Found duplicate script run. Stopping\n";
}

my $IOSTATS = '/usr/bin/iostat -xkd 30 2';
my $LVDISPLAY = '/usr/sbin/lvdisplay 2> /tmp/lvdisplay.err';
my $IOSTAT_CACHE = '/tmp/iostat.cache';
my $TEMP = "$IOSTAT_CACHE.tmp";

# Build a mapping of logical device names
my $cnt = '0';
my %device_map;

open my $lvinfo, '-|', $LVDISPLAY or die "Cannot open lvdisplay:$!\n";
while (my $line = <$lvinfo>) {
    if ($line =~ /LV Name/) {
        $device_map{"dm-$cnt"} = lc((split /\s+/, $line)[3]);
        $cnt++;
    }
}

# Generate iostats cache file
open my $in, '-|', $IOSTATS or die "Cannot open iostats:$!\n";
open my $out, '>', $TEMP or die "Cannot open $TEMP for writing:$!\n";
while (my $line = <$in>) {
    if ($line =~ /^(dm-\d+)/) {
        my $device = $device_map{$1};
        $line =~ s/dm-\d+/$device/;
    }
    print $out $line;
}

rename $TEMP, $IOSTAT_CACHE;
exit;

__DATA__
This exists to allow the locking code at the beginning of the file to work.
DO NOT REMOVE THESE LINES!
