#!/usr/bin/perl
use strict;
use LWP::Simple;
use Getopt::Long;
use XML::XPath; 
use XML::XPath::XMLParser;

use Fatal qw(open close);

my $project = undef;
my $comments = 1;
my  $result = GetOptions ("project=s" => \$project,
                          "comments"  => \$comments);
sub issues_url {
    my $project = shift;
    return "https://code.google.com/feeds/issues/p/$project/issues/full?max-results=1000000000&can=all";
}

sub comment_url {
    my ($project, $commentid) = @_;
    return "https://code.google.com/feeds/issues/p/$project/issues/$commentid/comments/full";
}

# get the issues
mkdir "./$project";
my $url = issues_url($project);
my $xml = GET( $url );
save("./$project/issues.xml",$xml);
my $xp = XML::XPath->new( xml => $xml );
my @ids = find_issue_ids( $xp );
my %h = map { my $id = $_; ($id, comment_url($id)) } @ids;
save("./$project/comments-urls.txt",values(%h));
foreach my $id (sort @ids) {
    my $url = $h{$id};
    my $xml = GET($url);
    save(sprintf("./$project/".'comments-%06d.xml', $id), $xml);
    sleep(5);
}

sub save {
    my ($file,@rest) = @_;
    open(my $fd, ">", $file);
    print $fd @rest;
    close($fd);
}

sub find_issue_ids {
    my ($xp) = @_;
    my $nodeset = $xp->find('/feed/entry/issues:id'); # find all subjects
    my @ids = map { my $node = $_; XML::XPath::XMLParser::as_string($node) } ($nodeset->get_nodelist);
    return @ids;
}
