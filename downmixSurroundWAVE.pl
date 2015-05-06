#!/usr/bin/perl

use strict;	# Enforce some good programming rules
use Getopt::Long;
use File::Find;

#
# Downmix-Surround-WAVE
# 
# take 6 mono WAVE files (5.1 mix)
# downmix to stereo and output
# 
# written by Theron Trowbridge
# http://therontrowbridge.com
#
# version 0.2
# created 2015-05-04
# modified 2015-05-06
# 

my ( $directory_param, $output_param, $recurse_param, $help_param, $version_param, $debug_param );
my ( @wave_files, $num_wave_files );
my ( $left_channel, $right_channel, $center_channel, $lfe_channel, $left_surround_channel, $right_surround_channel );
my ( $centermix_param, $surrmix_param, $lfemix_param, $gain_param );
my ( $analyze_param, $normalize_param, $limit_param, $bitdepth_param );

# get command line options
GetOptions( 'directory|d=s'	=>	\$directory_param,
			'output|o=s'	=>	\$output_param,
			'recurse|r!'	=>	\$recurse_param,
			'centermix=f'	=>	\$centermix_param,
			'surrmix=f'		=>	\$surrmix_param,
			'lfemix=f'		=>	\$lfemix_param,
			'gain=f'		=>	\$gain_param,
			'analyze!'		=>	\$analyze_param,
			'normalize=f'	=>	\$normalize_param,
			'limit!'		=>	\$limit_param,
			'bitdepth=i'	=>	\$bitdepth_param,
			'debug'			=>	\$debug_param,
			'help|?'		=>	\$help_param,
			'version'		=>	\$version_param );

if ( $debug_param ) {
	print "DEBUG: passed parameters:\n";
	print "directory_param: $directory_param\n";
	print "output_param: $output_param\n";
	print "recurse_param: $recurse_param\n";
	print "centermix_param: $centermix_param\n";
	print "surrmix_param: $surrmix_param\n";
	print "lfemix_param: $lfemix_param\n";
	print "gain_param: $gain_param\n";
	print "analyze_param: $analyze_param\n";
	print "normalize_param: $normalize_param\n";
	print "limit_param: $limit_param\n";
	print "bitdepth_param: $bitdepth_param\n";
	print "debug_param: $debug_param\n";
	print "help_param: $help_param\n";
	print "version_param: $version_param\n\n";
}

if ( $version_param ) {
	print "downmixSurroundWAVE.pl version 0.1\n";
	exit;
}

if ( $help_param ) {
	print "downmixSurroundWAVE.pl\n";
	print "version 0.1\n\n";
	print "--directory | -d <path>\n";
	print "\toptional - defaults to current working directory\n";
	print "--output | -o\n";
	print "\toutput file\n";
	print "\toptional - default is the left channel basename plus \"stereo.wav\"\n";
	print "--[no]recurse | -[no]r\n";
	print "\tlook in subfolders for WAVE files\n";
	print "\tdefault is false - only look in current working directory\n";
	print "--centermix <dB>\n";
	print "\tset downmix matrix value for center channel\n";
	print "\tif omitted, defaults to -3\n";
	print "--surrmix <dB>\n";
	print "\tset downmix matrix value for surround channels\n";
	print "\tif omitted, defaults to -9\n";
	print "--lfemix <dB>\n";
	print "\tset downmix matrix value for LFE channel\n";
	print "\tif omitted, defaults to -6\n";
	print "--gain <dB>\n";
	print "\toverall gain to be applied to stereo stream post downmix\n";
	print "\t(does not do anything yet\n";
	print "--[no]analyze\n";
	print "\tanalyze resulting output levels and report, without outputting\n";
	print "\treports min and max levels per channel,\n";
	print "\tand percentage of samples clipping\n";
	print "\toverrides --output, --normalize, --limit\n";
	print "\t(does not do anything yet\n";
	print "--normalize <dB>\n";
	print "\tnormalize output levels\n";
	print "\tno default value as undef is no normalization\n";
	print "\t(does not do anything yet\n";
	print "--[no]limit\n";
	print "\tdo soft peak limiting\n";
	print "\t(does not do anything yet\n";
	print "--bitdepth [16|24]\n";
	print "\tset the sample size of output file\n";
	print "\tdefault is 16 bit\n";
	print "--version\n";
	print "\tdisplay version number\n";
	print "--help | -?\n";
	print "\tdisplay this text\n";
	exit;
}

# set parameter defaults
if ( $directory_param eq undef ) { ; }
if ( $recurse_param eq undef ) { $recurse_param = 0; }
### output_param - left channel, with _stereo.wav appended
if ( $centermix_param eq undef ) { $centermix_param = -3; }
if ( $surrmix_param eq undef ) { $surrmix_param = -9; }
if ( $lfemix_param eq undef ) { $lfemix_param = -6; }
if ( $gain_param eq undef ) { $gain_param = 0; }
### the above probably need float validation
if ( $analyze_param eq undef ) { $analyze_param = 0; }
### normalize_param is a little weird - need to validate number
if ( $limit_param eq undef ) { $limit_param = 0; }
if ( $bitdepth_param eq undef ) { $bitdepth_param = 16; }

if ( $debug_param ) {
	print "DEBUG: adjusted parameters:\n";
	print "directory_param: $directory_param\n";
	print "output_param: $output_param\n";
	print "recurse_param: $recurse_param\n";
	print "centermix_param: $centermix_param\n";
	print "surrmix_param: $surrmix_param\n";
	print "lfemix_param: $lfemix_param\n";
	print "gain_param: $gain_param\n";
	print "analyze_param: $analyze_param\n";
	print "normalize_param: $normalize_param\n";
	print "limit_param: $limit_param\n";
	print "bitdepth_param: $bitdepth_param\n";
	print "debug_param: $debug_param\n";
	print "help_param: $help_param\n";
	print "version_param: $version_param\n\n";
}

# find all the WAVE files
find( \&find_wave_files, "." );

$num_wave_files = @wave_files;

if ( $debug_param ) { print "DEBUG: Number of WAVE files found: $num_wave_files\n"; }
if ( $debug_param ) { print "DEBUG: WAVE files: @wave_files\n"; }

# find left channel
for ( my $i = 0; $i < $num_wave_files; $i++ ) {
	if ( ( @wave_files[$i] =~ /_L\./i ) || ( @wave_files[$i] =~ /_LEFT\./i ) ) {
		$left_channel = @wave_files[$i];
	}
}
if ( $debug_param ) { print "DEBUG: Left WAVE file: $left_channel\n"; }

# find right channel
for ( my $i = 0; $i < $num_wave_files; $i++ ) {
	if ( ( @wave_files[$i] =~ /_R\./i ) || ( @wave_files[$i] =~ /_RIGHT\./i ) ) {
		$right_channel = @wave_files[$i];
	}
}
if ( $debug_param ) { print "DEBUG: Right WAVE file: $right_channel\n"; }

# find center channel
for ( my $i = 0; $i < $num_wave_files; $i++ ) {
	if ( ( @wave_files[$i] =~ /_C\./i ) || ( @wave_files[$i] =~ /_CENTER\./i ) ) {
		$center_channel = @wave_files[$i];
	}
}
if ( $debug_param ) { print "DEBUG: Center WAVE file: $center_channel\n"; }

# find LFE channel
for ( my $i = 0; $i < $num_wave_files; $i++ ) {
	if ( ( @wave_files[$i] =~ /_LFE\./i ) || ( @wave_files[$i] =~ /_SUB\./i ) ) {
		$lfe_channel = @wave_files[$i];
	}
}
if ( $debug_param ) { print "DEBUG: LFE WAVE file: $lfe_channel\n"; }

# find left surround channel
for ( my $i = 0; $i < $num_wave_files; $i++ ) {
	if ( ( @wave_files[$i] =~ /_LS\./i ) || ( ( @wave_files[$i] =~ /_LSUR\./i ) ) ) {
		$left_surround_channel = @wave_files[$i];
	}
}
if ( $debug_param ) { print "DEBUG: Left surround WAVE file: $left_surround_channel\n"; }

# find right surround channel
for ( my $i = 0; $i < $num_wave_files; $i++ ) {
	if ( ( @wave_files[$i] =~ /_RS\./i ) || ( @wave_files[$i] =~ /_RSUR\./i ) ) {
		$right_surround_channel = @wave_files[$i];
	}
}
if ( $debug_param ) { print "DEBUG: Right surround WAVE file: $right_surround_channel\n"; }

# make sure we have all the channels we need
if ( $left_channel eq undef ) { die "ERROR: can't find left channel WAVE file\n"; }
if ( $right_channel eq undef ) { die "ERROR: can't find right channel WAVE file\n"; }
if ( $center_channel eq undef ) { die "ERROR: can't find center channel WAVE file\n"; }
if ( $lfe_channel eq undef ) { die "ERROR: can't find LFE channel WAVE file\n"; }
if ( $left_surround_channel eq undef ) { die "ERROR: can't find left surround channel WAVE file\n"; }
if ( $right_surround_channel eq undef ) { die "ERROR: can't find right surround channel WAVE file\n"; }

# come up with our default output file name if one was not supplied
if ( $output_param eq undef ) {
	$output_param = $center_channel;
	$output_param =~ s/_[^_]*?\.wav$/_stereo\.wav/i;
}
if ( $debug_param ) { print "DEBUG: output file name: $output_param\n"; }

#####

# open each input file
# validate that they are all mono WAVE files
# validate that their spec is all the same (duration, bit depth, sampling rate, ???)
# figure out how many samples there are
# create output file
# generate the output header
# write output header
# 
# step through samples in input files
# read sample from each file
# convert to float values
# do downmix matrix
# write L/R samples to output file
# 

#####

# open each input file




## subroutines

# dB_to_coef
#
# convert decibel value to a coefficient for adjusting sample values
sub dB_to_coef { return( 10 ** ( @_[0] / 20 ) ); }


sub find_wave_files {
	if ( /\.wav$/i && ( $recurse_param || $File::Find::dir eq "." ) ) {
		push @wave_files, clean_path( $File::Find::name );
	}
}

sub clean_path {
	my $path = @_[0];
	$path =~ s/\\/\//g;		# turn around any backwards slashes
	$path =~ s/\/\.\//\//;	# remove extra "/./"
	$path =~ s/^\.\///;
	return( $path );

	###
	# 	this works on Mac/Linux and on Windows if all the WAVE files are local
	#	need to make sure we don't screw up file paths on Windows machines
	###

}

