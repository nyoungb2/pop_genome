#!/usr/bin/env perl

### modules
use strict;
use warnings;
use Pod::Usage;
use Data::Dumper;
use Getopt::Long;
use File::Spec;
use DBI;

### args/flags
pod2usage("$0: No files given.") if ((@ARGV == 0) && (-t STDIN));

my ($verbose, $db_file, $runID);
my $regex = ".+_|\.f[astn]*a\$";
GetOptions(
	   "database=s" => \$db_file,
	   "runID=s" => \$runID,
	   "regex=s" => \$regex,
	   "verbose" => \$verbose,
	   "help|?" => \&pod2usage # Help
	   );

### I/O error
check_file_IO($db_file, "database");
die " ERROR: provide a value for '-runID'\n" unless defined $runID;
$regex = qr/$regex/;

### MAIN
# connect 2 db #
my %attr = (RaiseError => 0, PrintError=>0, AutoCommit=>0);
my $dbh = DBI->connect("dbi:SQLite:dbname=$db_file", '','', \%attr) 
	or die " Can't connect to $db_file!\n";

# loading table #
load_clust_info($dbh, $runID, $regex);

# commit & disconnect #
$dbh->commit;
$dbh->disconnect();
exit;


### Subroutines
sub load_clust_info{
# loading bootstrap stats into rdtl-db #
	my ($dbh, $runID, $regex) = @_;
	
	my @cols = qw/clusterID runID pop value ci_low ci_high/;

	my $q = join("", 
			"INSERT INTO Fst(", join(",", @cols), 
			") VALUES(", join(",", ("?") x scalar @cols), ")"
			);
			
	my $sth = $dbh->prepare($q);

	my $entry_cnt = 0;	
	while(<>){
		chomp;
		next if /^\s*$/;
		my @l = split /\t/;
		die " ERROR: Fst table should have 4 columns!\n"
			unless scalar @l >= 4;
	
		# getting clusterID #
		(my $clusterID = $l[0]) =~ s/$regex//g;
	
		
		# getting low & high ci #
		my @tmp = split /\+-/, $l[3];
		my $low_ci = $tmp[0] - $tmp[1];
		my $high_ci = $tmp[0] + $tmp[1];
		
		$sth->execute($clusterID, $runID, $l[1], $l[2], $low_ci, $high_ci);
		if($DBI::err){
			print STDERR "ERROR: $DBI::errstr in: '$clusterID' \n";
			}
		else{ $entry_cnt++; }	
		}


	print STDERR " Number of entries added/updated in PopGen-db Fst table: $entry_cnt\n";		
	}


sub check_file_IO{
	my ($infile, $var) = @_;
	die " ERROR: provide a $var file!\n"
		unless $infile;
	die " ERROR: cannot find $infile!\n"
		unless -e $infile;
	}


__END__

=pod

=head1 NAME

PopGen-db_loadFst.pl -- loading a table of Fst values

=head1 SYNOPSIS

PopGen-db_loadFst.pl [flags]

=head2 Required flags

=over

=item -database  <char>

PopGen-db database file.

=item -runID  <char>

ITEP cluster run ID. 

=back

=head2 Optional flags

=over

=item -regex  <char>

Regex for pulling cluster ID out of colunn 1 values. [".+_|\.f[astn]*a\$"]

=item -verbose  <bool>

Verbose output. [FALSE]

=item -h	This help message

=back

=head2 For more information:

perldoc PopGen-db_loadFst.pl

=head1 DESCRIPTION

Load basic cluster info into PopGen-db.

=head1 EXAMPLES

=head2 Basic usage

PopGen-db_loadFst.pl -da PopGen-db.sqlite -r mazei_I_2.0_c_0.4_m_maxbit < Fst_res.txt

=head1 AUTHOR

Nick Youngblut <nyoungb2@illinois.edu>

=head1 AVAILABILITY

sharchaea.life.uiuc.edu:/home/git/ITEP_PopGen/

=head1 COPYRIGHT

Copyright 2010, 2011
This software is licensed under the terms of the GPLv3

=cut

