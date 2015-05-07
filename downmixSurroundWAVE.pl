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

# constants
use constant LEFT => 0;
use constant RIGHT => 1;
use constant CENTER => 2;
use constant LFE => 3;
use constant LEFT_SURROUND => 4;
use constant RIGHT_SURROUND => 5;

# variables
my ( $directory_param, $output_param, $recurse_param, $help_param, $version_param, $debug_param );
my ( @wave_files, $num_wave_files );
my ( $left_channel, $right_channel, $center_channel, $lfe_channel, $left_surround_channel, $right_surround_channel );
my ( $centermix_param, $surrmix_param, $lfemix_param, $gain_param );
my ( $centermix_coef, $surrmix_coef, $lfemix_coef, $gain_coef );
my ( $analyze_param, $normalize_param, $limit_param, $bitdepth_param );
my $result;
my $buffer;
my ( @file_size, @channels, @sample_rate, @bit_depth, @sample_chunk_size, @num_samples );
my ( @input_sample, @output_sample );
my ( $input_block_align, $input_byte_rate, $input_num_samples );
# output file header values
my $output_sub_chunk_1_size = 16;
my $output_audio_foramt = 1;
my $output_num_channels = 2;
my $output_sample_rate;			# use the input file sample rate
my $output_bits_per_sample;		# defined by user
my $output_block_align;			# calculated	= ceil( $num_channels * int( $bits_per_sample / 8 ) );
my $output_byte_rate;			# calculated	= $sample_rate * $block_align;
my $output_data_size;

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

$centermix_coef = dB_to_coef( $centermix_param );
$surrmix_coef = dB_to_coef( $surrmix_param );
$lfemix_coef = dB_to_coef( $lfemix_param );
$gain_coef = dB_to_coef( $gain_param );

if ( $debug_param ) {
	print "DEBUG: downmix coefficients:\n";
	print "centermix_coef: $centermix_coef\n";
	print "surrmix_coef: $surrmix_coef\n";
	print "lfemix_coef: $lfemix_coef\n";
	print "gain_coef: $gain_coef\n\n";
}


# find all the WAVE files
find( \&find_wave_files, "." );

$num_wave_files = @wave_files;

if ( $debug_param ) { print "DEBUG: Number of WAVE files found: $num_wave_files\n"; }
#if ( $debug_param ) { print "DEBUG: WAVE files: @wave_files\n"; }

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
if ( $debug_param ) { print "DEBUG: Right surround WAVE file: $right_surround_channel\n\n"; }

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
if ( $debug_param ) { print "DEBUG: output file name: $output_param\n\n"; }


# open each input file and get their sizes

# open left channel file
$result = open( LEFT_CHANNEL, "<", $left_channel )
	or die "$left_channel: error: could not open file $!\n";
binmode( LEFT_CHANNEL );

@file_size[ LEFT ] = -s LEFT_CHANNEL;

# open right channel file
$result = open( RIGHT_CHANNEL, "<", $right_channel )
	or die "$right_channel: error: could not open file $!\n";
binmode( RIGHT_CHANNEL );

@file_size[ RIGHT ] = -s RIGHT_CHANNEL;

# open center channel file
$result = open( CENTER_CHANNEL, "<", $center_channel )
	or die "$center_channel: error: could not open file $!\n";
binmode( CENTER_CHANNEL );

@file_size[ CENTER ] = -s CENTER_CHANNEL;

# open LFE channel file
$result = open( LFE_CHANNEL, "<", $lfe_channel )
	or die "$lfe_channel: error: could not open file $!\n";
binmode( LFE_CHANNEL );

@file_size[ LFE ] = -s LFE_CHANNEL;

# open left surround channel file
$result = open( LEFT_SURROUND_CHANNEL, "<", $left_surround_channel )
	or die "$left_surround_channel: error: could not open file $!\n";
binmode( LEFT_SURROUND_CHANNEL );

@file_size[ LEFT_SURROUND ] = -s LEFT_SURROUND_CHANNEL;

# open right surround channel file
$result = open( RIGHT_SURROUND_CHANNEL, "<", $right_surround_channel )
	or die "$right_surround_channel: error: could not open file $!\n";
binmode( RIGHT_SURROUND_CHANNEL );

@file_size[ RIGHT_SURROUND ] = -s RIGHT_SURROUND_CHANNEL;

if ( $debug_param ) {
	print "DEBUG: left channel size: $file_size[ LEFT ]\n";
	print "DEBUG: right channel size: $file_size[ RIGHT ]\n";
	print "DEBUG: center channel size: $file_size[ CENTER ]\n";
	print "DEBUG: LFE channel size: $file_size[ LFE ]\n";
	print "DEBUG: left surround channel size: $file_size[ LEFT_SURROUND ]\n";
	print "DEBUG: right surround channel size: $file_size[ RIGHT_SURROUND ]\n\n";
}

# check to see if they are all the same size
if ( ( @file_size[LEFT] ne @file_size[RIGHT] ) || ( @file_size[LEFT] ne @file_size[CENTER] ) ||
	( @file_size[LEFT] ne @file_size[LFE] ) || ( @file_size[LEFT] ne @file_size[LEFT_SURROUND] ) ||
	( @file_size[LEFT] ne @file_size[RIGHT_SURROUND] ) ) {
	
	print "WARNING: input files are not the same size\n";
}
### for now, we're going to proceed, but we might want to error out in this case


## let's do this in a really inefficient way for the moment :)
## but at least we only have to do it once

# number of channels
@channels[LEFT] = get_num_channels( \*LEFT_CHANNEL );
@channels[RIGHT] = get_num_channels( \*RIGHT_CHANNEL );
@channels[CENTER] = get_num_channels( \*CENTER_CHANNEL );
@channels[LFE] = get_num_channels( \*LFE_CHANNEL );
@channels[LEFT_SURROUND] = get_num_channels( \*LEFT_SURROUND_CHANNEL );
@channels[RIGHT_SURROUND] = get_num_channels( \*RIGHT_SURROUND_CHANNEL );

if ( ( @channels[LEFT] ne @channels[RIGHT] ) || ( @channels[LEFT] ne @channels[CENTER] ) ||
	( @channels[LEFT] ne @channels[LFE] ) || ( @channels[LEFT] ne @channels[LEFT_SURROUND] ) ||
	( @channels[LEFT] ne @channels[RIGHT_SURROUND] ) ) {
	
	print "WARNING: not all input files are mono\n";
}
### for now, we're going to proceed, but we might want to error out in this case

# sampling rate
@sample_rate[LEFT] = get_sample_rate( \*LEFT_CHANNEL );
@sample_rate[RIGHT] = get_sample_rate( \*RIGHT_CHANNEL );
@sample_rate[CENTER] = get_sample_rate( \*CENTER_CHANNEL );
@sample_rate[LFE] = get_sample_rate( \*LFE_CHANNEL );
@sample_rate[LEFT_SURROUND] = get_sample_rate( \*LEFT_SURROUND_CHANNEL );
@sample_rate[RIGHT_SURROUND] = get_sample_rate( \*RIGHT_SURROUND_CHANNEL );

if ( ( @sample_rate[LEFT] ne @sample_rate[RIGHT] ) || ( @sample_rate[LEFT] ne @sample_rate[CENTER] ) ||
	( @sample_rate[LEFT] ne @sample_rate[LFE] ) || ( @sample_rate[LEFT] ne @sample_rate[LEFT_SURROUND] ) ||
	( @sample_rate[LEFT] ne @sample_rate[RIGHT_SURROUND] ) ) {
	
	print "WARNING: not all input files are the same sampling rate\n";
}
### for now, we're going to proceed, but we might want to error out in this case

# bit depth
@bit_depth[LEFT] = get_bit_depth( \*LEFT_CHANNEL );
@bit_depth[RIGHT] = get_bit_depth( \*RIGHT_CHANNEL );
@bit_depth[CENTER] = get_bit_depth( \*CENTER_CHANNEL );
@bit_depth[LFE] = get_bit_depth( \*LFE_CHANNEL );
@bit_depth[LEFT_SURROUND] = get_bit_depth( \*LEFT_SURROUND_CHANNEL );
@bit_depth[RIGHT_SURROUND] = get_bit_depth( \*RIGHT_SURROUND_CHANNEL );

if ( ( @bit_depth[LEFT] ne @bit_depth[RIGHT] ) ||
	( @bit_depth[LEFT] ne @bit_depth[CENTER] ) ||
	( @bit_depth[LEFT] ne @bit_depth[LFE] ) ||
	( @bit_depth[LEFT] ne @bit_depth[LEFT_SURROUND] ) ||
	( @bit_depth[LEFT] ne @bit_depth[RIGHT_SURROUND] ) ) {
	
	print "WARNING: not all input files are the same bit depth\n";
}
### for now, we're going to proceed, but we might want to error out in this case

# we can use the left channel values for the output header, adjusted for stereo

# @sample_chunk_size
# for each file, find the data chunk and remember how many bytes long it is
@sample_chunk_size[LEFT] = find_WAVE_data( \*LEFT_CHANNEL );
@sample_chunk_size[RIGHT] = find_WAVE_data( \*RIGHT_CHANNEL );
@sample_chunk_size[CENTER] = find_WAVE_data( \*CENTER_CHANNEL );
@sample_chunk_size[LFE] = find_WAVE_data( \*LFE_CHANNEL );
@sample_chunk_size[LEFT_SURROUND] = find_WAVE_data( \*LEFT_SURROUND_CHANNEL );
@sample_chunk_size[RIGHT_SURROUND] = find_WAVE_data( \*RIGHT_SURROUND_CHANNEL );

if ( ( @sample_chunk_size[LEFT] ne @sample_chunk_size[RIGHT] ) ||
	( @sample_chunk_size[LEFT] ne @sample_chunk_size[CENTER] ) ||
	( @sample_chunk_size[LEFT] ne @sample_chunk_size[LFE] ) ||
	( @sample_chunk_size[LEFT] ne @sample_chunk_size[LEFT_SURROUND] ) ||
	( @sample_chunk_size[LEFT] ne @sample_chunk_size[RIGHT_SURROUND] ) ) {
	
	print "WARNING: not all input files have the same data chunk size\n";
}
### for now, we're going to proceed, but we might want to error out in this case

# figure out our output WAVE header values
$output_sample_rate = @sample_rate[LEFT];						# use input file sampling rate
$output_bits_per_sample = $bitdepth_param;						# use the requested bit depth
$output_block_align = ceil( 2 * int( @bit_depth[LEFT] / 8 ) );	# calculate
$output_byte_rate = $output_block_align * @sample_rate[LEFT];	# calculated

# need to figure out how many samples total to expect
$input_block_align = ceil( @channels[LEFT] * int( @bit_depth[LEFT] / 8 ) );
$input_byte_rate = $input_block_align * @sample_rate[LEFT];
$input_num_samples = @sample_chunk_size[LEFT] / $input_block_align;

# easy!

# create output file
if ( $debug_param ) { print "DEBUG: creating output file $output_param\n\n"; }
open( OUTPUT, ">", $output_param ) or die "Can't open file $output_param\n";
binmode( OUTPUT );

# need to figure out how big our output data will be
# which will determine how big our file will be
$output_data_size = $output_block_align * $input_num_samples;

# so now, we can write our RIFF and WAVE headers
print OUTPUT "RIFF";
print OUTPUT pack( 'L', ( $output_data_size + 36 ) );
print OUTPUT "WAVE";
print OUTPUT "fmt ";								# fmt chunk id
print OUTPUT pack( 'L', 16 );						# sub chunk 1 size
print OUTPUT pack( 'S', 1 );						# audio format
print OUTPUT pack( 'S', 2 );						# num channels
print OUTPUT pack( 'L', $output_sample_rate );		# sample rate
print OUTPUT pack( 'L', $output_byte_rate );		# byte rate
print OUTPUT pack( 'S', $output_block_align );		# block align
print OUTPUT pack( 'S', $output_bits_per_sample );	# bits per sample

# and then we can write out the start of the data chunk
print OUTPUT "data";								# data chunk id
print OUTPUT pack( 'L', $output_data_size );		# data chunk size

# now all that's left is the audio data!
# easy, right?!?!?
# yeah...



### TESTS:
# note that the unpack command here works for 16 bit signed
# but won't work for 24 bit
# need to figure out how to make it universal
# probably move to a subroutine

$result = read( LEFT_CHANNEL, $buffer, $input_block_align );
@input_sample[LEFT] = unpack( "s", $buffer );

$result = read( RIGHT_CHANNEL, $buffer, $input_block_align );
@input_sample[RIGHT] = unpack( "s", $buffer );

$result = read( CENTER_CHANNEL, $buffer, $input_block_align );
@input_sample[CENTER] = unpack( "s", $buffer );

$result = read( LFE_CHANNEL, $buffer, $input_block_align );
@input_sample[LFE] = unpack( "s", $buffer );

$result = read( LEFT_SURROUND_CHANNEL, $buffer, $input_block_align );
@input_sample[LEFT_SURROUND] = unpack( "s", $buffer );

$result = read( RIGHT_SURROUND_CHANNEL, $buffer, $input_block_align );
@input_sample[RIGHT_SURROUND] = unpack( "s", $buffer );


print "***** $input_sample[LEFT] *****\n";
print "***** $input_sample[RIGHT] *****\n";
print "***** $input_sample[CENTER] *****\n";
print "***** $input_sample[LFE] *****\n";
print "***** $input_sample[LEFT_SURROUND] *****\n";
print "***** $input_sample[RIGHT_SURROUND] *****\n";

### TESTS


# my ( @input_sample, @output_sample );
# $result = read( $file_ptr, $buffer, 8 );


#####

# step through samples in input files
# read sample from each file
# convert to float values
# 	make -1 .. 1 or 0 .. 1???
# do downmix matrix
# quantize to output bit depth
# write L/R samples to output file
# 

#####




# clean up
close( LEFT_CHANNEL );
close( RIGHT_CHANNEL );
close( CENTER_CHANNEL );
close( LFE_CHANNEL );
close( LEFT_SURROUND_CHANNEL );
close( RIGHT_SURROUND_CHANNEL );

## subroutines

# ceil()
# my quick-and-dirty version of the POSIX function
# because the POSIX module seems to cause issues here for some reason
sub ceil {
	my $input_value = shift;
	my $output_value = int( $input_value );
	if ( ( $input_value - $output_value ) > 0 ) { $output_value++; }
	return( $output_value );
}

# dB_to_coef()
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

#	short_value()
#	convert argument into little-endian unsigned short
sub short_value {
	return( unpack( "S<", $_[0] ) );
}

#	long_value()
#	convert argument into little-endian unsigned long
sub long_value {
	return( unpack( "L<", $_[0] ) );
}


sub find_WAVE_header {
	my $file_ptr = @_[0];
	my $done = 0;
	my ( $result, $buffer, $result, $read_chunk_id, $read_chunk_size );
	
	seek( $file_ptr, 12, 0 );						# skip past the end of the RIFF header
	
	while( !$done ) {
		$result = read( $file_ptr, $buffer, 8 );
		if ( $result eq 0 ) {						# end of file
			seek( $file_ptr, 0, 0 );				# rewind file
			return( 0 );							# return 0, which indicates an error
		}
		
		$read_chunk_id = substr( $buffer, 0, 4 );						# get chunk ID
		$read_chunk_size = long_value( substr( $buffer, 4, 4 ) );		# get chunk size
		
		if ( $read_chunk_id eq "fmt " ) { return( $read_chunk_size ); }	# return chunk size
		else { seek( $file_ptr, $read_chunk_size, 1 ); }				# seek to next chunk
	}
}

sub find_WAVE_data {
	my $file_ptr = @_[0];
	my $done = 0;
	my ( $result, $buffer, $result, $read_chunk_id, $read_chunk_size );
	
	seek( $file_ptr, 12, 0 );						# skip past the end of the RIFF header
	
	while( !$done ) {
		$result = read( $file_ptr, $buffer, 8 );
		if ( $result eq 0 ) {						# end of file
			seek( $file_ptr, 0, 0 );				# rewind file
			return( 0 );							# return 0, which indicates an error
		}
		
		$read_chunk_id = substr( $buffer, 0, 4 );						# get chunk ID
		$read_chunk_size = long_value( substr( $buffer, 4, 4 ) );		# get chunk size
		
		if ( $read_chunk_id eq "data" ) { return( $read_chunk_size ); }	# return chunk size
		else { seek( $file_ptr, $read_chunk_size, 1 ); }				# seek to next chunk
	}
}

sub get_num_channels {
	my $file_ptr = shift;
	my $header;
	my $chunk_size;
	my $result;
	my $num_channels;
	$chunk_size = find_WAVE_header( $file_ptr );
	if ( $chunk_size ne 16 ) { print "WARNING: unusual size WAVE header found\n"; }
	
	$result = read( $file_ptr, $header, $chunk_size );
	if ( $result eq undef ) { print "WARNING: could not read WAVE header\n"; }
	
	$num_channels = short_value( substr( $header, 2, 2 ) );
	return( $num_channels );
}

sub get_sample_rate {
	my $file_ptr = shift;
	my $header;
	my $chunk_size;
	my $result;
	my $sample_rate;
	$chunk_size = find_WAVE_header( $file_ptr );
	if ( $chunk_size ne 16 ) { print "WARNING: unusual size WAVE header found\n"; }
	
	$result = read( $file_ptr, $header, $chunk_size );
	if ( $result eq undef ) { print "WARNING: could not read WAVE header\n"; }
	
	$sample_rate = long_value( substr( $header, 4, 4 ) );
	return( $sample_rate );
}

sub get_bit_depth {
	my $file_ptr = shift;
	my $header;
	my $chunk_size;
	my $result;
	my $bits_per_sample;
	$chunk_size = find_WAVE_header( $file_ptr );
	if ( $chunk_size ne 16 ) { print "WARNING: unusual size WAVE header found\n"; }
	
	$result = read( $file_ptr, $header, $chunk_size );
	if ( $result eq undef ) { print "WARNING: could not read WAVE header\n"; }
	
	$bits_per_sample = short_value( substr( $header, 14, 2 ) );
	return( $bits_per_sample );
}

## block_align and byte_rate are calculated so no need to extract them
##
# 		# WAVE header values
# 		$audio_format = short_value( substr( $header, 0, 2 ) );
# 		$num_channels = short_value( substr( $header, 2, 2 ) );
# 		$sample_rate = long_value( substr( $header, 4, 4 ) );
# 		$byte_rate = long_value( substr( $header, 8, 4 ) );
# 		$block_align = short_value( substr( $header, 12, 2 ) );
# 		$bits_per_sample = short_value( substr( $header, 14, 2 ) );



