#!/usr/bin/env perl
#######################################################################
#
# COPYRIGHT NOTICE
#
# autoMLSA-fasta_rename.pl - Auxillary script to rename FASTA entries
# without concatenating them.  Useful if you use autoMLSA.pl to 
# download individual sequences without needing filtering and 
# concatenation.
#
# Copyright (C) 2015
# Edward Davis
# Jeff Chang
#
# This file is a part of autoMLSA.
#
# autoMLSA is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# autoMLSA is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more detail.
#
# You should have received a copy of the GNU General Public License
# along with autoMLSA.  If not, see <http://www.gnu.org/licenses/>.
#
#######################################################################
use warnings;
use strict;

use Pod::Usage;
use Getopt::Long;
use Bio::SeqIO;

my $infile;
my $keyfile;
my %headers;
my $strain = 0;
my %seen;
my $log = "header_rename.log";
my $help = 0;
my $header = 0;

if (scalar(@ARGV) == 0) {
    pod2usage( -verbose => 1 ); 
}

GetOptions( 
            'strain'    => \$strain ,
            'header'    => \$header,
            'h|help'    => \$help,
            'keyfile=s' => \$keyfile
          );

if ($help) {
    pod2usage( -verbose => 1);
}
if ($header == 0) {
    $infile = shift;
    die "Cannot find infile: $infile\n"   if ( !-e $infile );
}
die "Cannot find keyfile: $keyfile\n" if ( !-e $keyfile );

open my $keyfh, "<", "$keyfile" or die "Unable to open keyfile : $!";
#Load hash with keyfile data
#Current format is Accession,AssemblyID,TaxID,SciName,GI,Master,GenBankName,Country,Source,Strain,CultureCollection,Year
#                  $match        0        1      2    3    4         5         6       7      8          9           10
while (<$keyfh>) {
    my $line = $_;
    chomp($line);
    my ( $accn, @values ) = split( "\t", $line );

    #Choose appropriate header name
    my $sciname = $values[2];
    my $gbname  = $values[5];
    my $header  = $sciname;
    my @test = split( " ", $sciname );  #Test for quality of name from taxid
    my $test = @test;
    my @test2 = split( " ", $gbname );
    my $test2 = @test2;
    my $candidatus = 0;
    my $subsp = 0;
    if ($sciname =~ /candidatus/i ) {
        $candidatus = 1;
    }
    if ($sciname =~ /pv\.|bv\.|subsp\./i ) {
        $subsp = 2;
    }
    my $value = 2 + $candidatus + $subsp;
    if ( $test == $value ) {
        if ( $gbname ne 'NULL' ) {
            if ( $sciname ne $gbname ) {
                $header = $gbname;
            }
        }
    }

    $header =~ tr/ ()[]':/_{}{}__/;
    $header =~ s/,//;
    if ($strain) {
        $header =~ s/strain_//;
        $header =~ s/str\._//;
    }

    $headers{$accn} = $header;
}

close $keyfh;

if ($header > 0) {
    foreach my $accn (sort keys %headers) {
        print join("\t",$accn,$headers{$accn})."\n";
    }
    exit(0);
}

open my $logfh, ">", $log or die "Unable to open logfile $log : $!";

#Setup new SeqIO stream
my $in = Bio::SeqIO->new( -file   => "$infile",
                          -format => 'fasta' );
my $out = Bio::SeqIO->new( -fh     => \*STDOUT,
                           -format => 'fasta' );
#Cycle through each sequence object in the SeqIO stream
while ( my $seq = $in->next_seq() ) {
    my $id  = $seq->id;
    if ( exists( $headers{$id} ) ) {
        $header = $headers{$id};
        if (! exists( $seen{$header} ) ) {
            $seen{$header} = 1;
        } else {
            print STDERR "Seen header: $header\n";
            $seen{$header}++;
            $header .= "_$seen{$header}";
        }
        print $logfh join("\t",$id,$headers{$id})."\n";
        $seq->id("$headers{$id}");
        $out->write_seq($seq);
    } else {
        $out->write_seq($seq);
    }

    print "\n";
}

__END__

=head1 NAME

autoMLSA-fasta_rename.pl - Rename FASTA-formatted sequences based on keyfile information

=head1 SYNOPSIS

autoMLSA.pl -keyfile all.keys gene.all.fas

=head1 OPTIONS

Defaults shown in square brackets.  Possible values shown in parentheses.

=over 8

=item B<-help|h>

Print a brief help message and exits.

=item B<-header>

Print re-naming information and exit. Does NOT rename the sequences.

=item B<-keyfile>

Path to keyfile (all.keys) generated by autoMLSA script.
