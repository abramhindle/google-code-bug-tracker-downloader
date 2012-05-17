#!/usr/bin/perl
use strict;
use LWP::Simple qw(get);
use LWP::UserAgent;
use Getopt::Long;
use XML::XPath; 
use XML::XPath::XMLParser;

use Fatal qw(open close);
use List::Util qw(min max);

foreach my $arg (@ARGV) {
    eval {
        my $xml = load($arg);
        my $xp = XML::XPath->new( xml => $xml );
        my @ids = find_issue_ids( $xp );
        my $min = min(@ids);
        my $max = max(@ids);
        my $n = scalar(@ids);
        print join("\t",$arg, $n, $min, $max),$/;
        #print join("\t",sort { $a <=> $b } @ids),$/;
    };
    if ($@) {
        warn "Could not handle $arg";
    }
}

sub find_issue_ids {
    my ($xp) = @_;
    my $nodeset = $xp->find('/feed/entry/issues:id/text()'); # find all subject
    my @ids = map { my $node = $_; $node->XML::XPath::XMLParser::as_string($node) } ($nodeset->get_nodelist);
    return @ids;
}
sub load {
    my ($filename) = @_;
    open(my $fd, $filename);
    my @lines = <$fd>;
    close($fd);
    return join("",@lines);
}
