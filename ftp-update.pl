#!/usr/bin/perl
use 5.010;
use strict;
use warnings;
use Getopt::Long;

my $STATUS = {
	w => 'WAITING',
	p => 'PREDOWN',
	d => 'DOWNING',
	f => 'FINISHD',
	i => 'INTERPT',
};

$SIG{'INT'} = \&handler;
$SIG{'QUIT'} = \&handler;

my %locked;

my %conf = get_config('ftp-watcher.conf');
my $work_folder = $conf{'ftp-work-root'};
my $status_file = $work_folder.'/'.$conf{'ftp-st-file'};
my $download_folder = $work_folder.'/'.$conf{'ftp-dl-path'};
my $ftp_tool = $conf{'ftp-tool-root'}.'/'.$conf{'ftp-tool'};
my $time_interval = $conf{'time-interval'};

exit unless -f $status_file;
lock_file($status_file);

open my $fh, "< $status_file";
my @local_status = <$fh>;
close $fh;

my @new_status;
my @targets;
my $time_stamp = time;
foreach my $line (@local_status) {
	chomp $line;
	next unless $line;

	my ($local_s, $local_p, $local_f, $local_z) = split(':', $line);

	if ($local_s eq $STATUS->{p} || $local_s eq $STATUS->{i}) {
		push @new_status, $STATUS->{d}.":$local_p:$local_f:$local_z:".$time_stamp;
		push @targets, "$local_p/$local_f";
		$time_stamp += $time_interval;
	}
	else {
		push @new_status, $line;
	}
}

open $fh, "> $status_file";
print $fh join "\n", @new_status;
print $fh "\n";
close $fh;

unlock_file($status_file);

my @work_pids;
foreach my $path (@targets) {
	my $pid = fork();
	if ($pid) {
		push @work_pids, $pid;
		sleep $time_interval;
	}
	elsif (defined $pid && $pid == 0) {
		say $path;
		download($path);

		exit 0;
	}
}

foreach my $child (@work_pids) {
    waitpid($child, 0);
}

sub get_config {
	my $config_file = shift;

	open my $CF, "< $config_file" or die 'cannot open file : '.$config_file;
	my @file_content = <$CF>;
	close $CF;

	my %configs;
	foreach my $line (@file_content) {
		chomp $line;

		next if $line =~ m/^\s*#/;
		next if $line !~ m/=/;

		if ($line =~ m{^\s*(.*?)\s*=\s*(.*)\s*$}) {
			$configs{$1} = $2;
		}
	}

	return %configs;
}

sub download {
	my $path = shift;

	system("${ftp_tool}-get.exp ${ftp_tool}.conf '$path' '$download_folder'");

	my $local_f = $path;
	$local_f =~ s/.*\///;
	change_status($local_f, $STATUS->{d}, $STATUS->{f});
}

sub lock_file {
	my $file = shift;

	while (-e "$file.lock") {
		sleep 5;
	}
	`touch $file.lock`;
	$locked{$file} = 1;
}

sub unlock_file {
	my $file = shift;

	if (exists $locked{$file} && $locked{$file}) {
		`rm -f $file.lock`;
	}
}

sub change_status {
	my $local_f = shift;
	my $old_status = shift;
	my $status = shift;

	lock_file($status_file);

	open my $fh, "< $status_file";
	my @local_status = <$fh>;
	close $fh;

	foreach (@local_status) {
		s/^${old_status}/${status}/;
	}

	open my $fh, "> $status_file";
	print $fh join '', @local_status;
	close $fh;

	unlock_file($status_file);
}

sub handler {
	foreach my $path (@targets) {
		my $local_f = $path;
		$local_f =~ s/.*\///;

		change_status($local_f, $STATUS->{d}, $STATUS->{i});
	}

	unlock_file($status_file);
	exit;
}
