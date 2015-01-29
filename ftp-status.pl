#!/usr/bin/perl
use 5.010;
use strict;
use warnings;

my $STATUS = {
	w => 'WAITING',
	p => 'PREDOWN',
	d => 'DOWNING',
	f => 'FINISHD',
	i => 'INTERPT',
};

my %conf = get_config('/etc/ftp-watcher/ftp-watcher.conf');
my $work_folder = $conf{'ftp-work-root'};
my $status_file = $work_folder.'/'.$conf{'ftp-st-file'};
my $download_folder = $work_folder.'/'.$conf{'ftp-dl-path'};

exit unless -e $status_file;

open my $fh, "< $status_file";
my @local_status = <$fh>;
close $fh;

foreach my $line (@local_status) {
	chomp $line;
	next unless $line;

	my ($local_s, $local_p, $local_f, $local_z, $local_t) = split(':', $line);
	my $local_path = get_local_path("$local_p/");

	my $crt_size = 0;
	my $percent = 0;
	my $time_elapse = 0;
	if (-e "$local_path/$local_f") {
		$crt_size = `wc -c "$local_path/$local_f" | awk '{print \$1}'`;
		$percent = $crt_size / $local_z * 100;
		$time_elapse = time - $local_t if $local_t;
	}

	if ($local_s eq $STATUS->{d}) {
		printf " %5.1f%% Elapse: %02d:%02d:%02d - %s\n",
			$percent,
			$time_elapse / 3600,
			$time_elapse % 3600 / 60,
			$time_elapse % 60,
			$local_f;
	}
	elsif ($local_s eq $STATUS->{w}) {
		printf " %5.1f%% %-16s - %s\n",
			0,
			"Waiting",
			$local_f;
	}
	elsif ($local_s eq $STATUS->{p}) {
		printf " %5.1f%% %-16s - %s\n",
			0,
			"Ready to start",
			$local_f;
	}
	elsif ($local_s eq $STATUS->{f}) {
		printf " %5.1f%% %-16s - %s\n",
			$percent,
			"Finished",
			$local_f;
	}
	elsif ($local_s eq $STATUS->{i}) {
		printf " %5.1f%% %-16s - %s\n",
			$percent,
			"Interrupted",
			$local_f;
	}
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

sub get_local_path {
	my $ftp_path = shift;

	my $local_path = "$download_folder/$ftp_path";
	$local_path =~ s/\/+[^\/]*^//;

	return $local_path;
}
