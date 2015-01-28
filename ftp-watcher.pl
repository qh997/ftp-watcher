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
};

my %locked;

$SIG{'INT'} = \&handler;
$SIG{'QUIT'} = \&handler;

my %conf = get_config('ftp-watcher.conf');
my $work_folder = $conf{'ftp-work-root'};
my $download_folder = $work_folder.'/'.$conf{'ftp-dl-path'};
my $status_file = $work_folder.'/'.$conf{'ftp-st-file'};
my $ftp_tool = $conf{'ftp-tool-root'}.'/'.$conf{'ftp-tool'};
my @ftp_paths = get_paths('ftp-paths.conf');

lock_file($status_file);

foreach my $ftp_path (@ftp_paths) {
	$ftp_path =~ s/#.*//;
	$ftp_path =~ s/^\s+//;
	$ftp_path =~ s/\s+$//;
	$ftp_path =~ s/\/+$//;

	next unless $ftp_path;

	my %ftp_files;
	foreach my $line (readpipe("${ftp_tool}-ls.exp ${ftp_tool}.conf '${ftp_path}'")) {
		chomp $line;
		$line =~ s/\r//g;
		if ($line =~ m/^[-rwx]{10}\s+(?:\d+\s+){3}(\d+)\s+(?:[\w:]+\s+){3}(.*)$/) {
			my $file = $2;
			my $size = $1;
			$ftp_files{$file} = $size;
		}
	}

	`touch $status_file` unless -f $status_file;

	open my $fh, "< $status_file";
	my @pre_status = <$fh>;
	close $fh;

	my @new_status;
	foreach my $line (@pre_status) {
		chomp $line;
		next unless $line;

		my ($local_s, $local_p, $local_f, $local_z) = split(':', $line);

		if (exists $ftp_files{$local_f}) {
			if ($local_s eq $STATUS->{w} && $ftp_files{$local_f} == $local_z) {
				push @new_status, $STATUS->{p}.":$local_p:$local_f:$ftp_files{$local_f}";
			}
			else {
				push @new_status, $line;
			}

			delete $ftp_files{$local_f};
		}
	}

	foreach my $ftp_f (keys %ftp_files) {
		push @new_status, $STATUS->{w}.":$ftp_path:$ftp_f:$ftp_files{$ftp_f}";
	}

	open $fh, "> $status_file";
	print $fh join "\n", @new_status;
	print $fh "\n";
	close $fh;
}

unlock_file($status_file);

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

sub get_paths {
	my $cfg_file = shift;

	open my $fh, '<', $cfg_file;
	my @list = <$fh>;
	close $fh;

	return @list;
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

sub handler {
	unlock_file($status_file);
	exit;
}
