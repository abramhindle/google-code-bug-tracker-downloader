#!/usr/bin/perl
use strict;
use LWP::Simple qw(get);
use LWP::UserAgent;
use Getopt::Long;
use XML::XPath; 
use XML::XPath::XMLParser;
use XML::DOM;


use Fatal qw(open close);

my $ua = LWP::UserAgent->new();

my $project = undef;
my $comments = 1;
my  $result = GetOptions ("project=s" => \$project,
                          "comments=i"  => \$comments);
sub issues_url {
    my ($project,$n) = @_;
    $n = (defined($n)?$n:0);
    my $m = 1+1000*int($n);
    return "https://code.google.com/feeds/issues/p/$project/issues/full?max-results=1000&can=all&start-index=${m}";
}

sub comment_url {
    my ($project, $commentid) = @_;
    return "https://code.google.com/feeds/issues/p/$project/issues/$commentid/comments/full";
}

# get the issues
mkdir "./$project";
my $issuesfilename = "./$project/issues.xml";
my $xml;
if (-e $issuesfilename) {
    warn "Already have the issues!";
    $xml = load($issuesfilename);
} else {
    $xml = retrieve_issues($project);
}
my $xp = XML::XPath->new( xml => $xml );
my @ids = find_issue_ids( $xp );
my %h = map { my $id = $_; ($id, comment_url($project,$id)) } @ids;
save("./$project/comments-urls.txt",join($/,values(%h)));
warn "Issues: ".scalar(@ids). "\t ".join("\t",@ids[0..10]);

die "Done" unless $comments;

foreach my $id (sort @ids) {
    my $url = $h{$id};
    my $filename = sprintf("./$project/".'comments-%06d.xml', $id);
    if (-e $filename) {
        warn "$filename already exists, skipping";
    } else {
        my $xml = GET($url);
        save($filename, $xml);
        my $sleep = int(1 + rand(3));
        warn "Sleeping for $sleep seconds";
        sleep($sleep);
    }
}

sub save {
    my ($file,@rest) = @_;
    open(my $fd, ">", $file);
    print $fd @rest;
    close($fd);
}

sub find_issue_ids {
    my ($xp) = @_;
    my $nodeset = $xp->find('/feed/entry/issues:id/text()'); # find all subject
    my @ids = map { my $node = $_; $node->XML::XPath::XMLParser::as_string($node) } ($nodeset->get_nodelist);
    return @ids;
}

sub GET {
    my ($uri,$retries) = @_;
    my $retries = (defined($retries)?$retries:3);
    warn(@_);
    my $res = $ua->get($uri);
    unless ($res->is_success()) {
        warn "Not successful!";
        if ($retries > 0) {
            sleep 30*( 3 - $retries );
            return GET($uri,abs($retries - 1));
        } else {
            die "Couldn't get $uri";
        }
    }
    return $res->content();
}

sub load {
    my ($filename) = @_;
    open(my $fd, $filename);
    my @lines = <$fd>;
    close($fd);
    return join("",@lines);
}
sub retrieve_issues {
    my ($project,$n,@xmls) = @_;
    $n = (defined($n)?$n:0);
    my $url = issues_url($project,$n);
    my $issuesfilename = "./$project/issues.xml";
    my $tmpissuesfilename = "./$project/.issues.$n.xml";
    my $xml;
    if (-e $tmpissuesfilename) {
        $xml = load($tmpissuesfilename);
    } else {
        $xml = GET( $url );
    }
    save($tmpissuesfilename, $xml);
    push @xmls, $xml;
    
    # get the number of elements
    my $xp = XML::XPath->new( xml => $xml );
    my @ids = find_issue_ids( $xp );
    if (@ids == 1000) {
        # ok so we need to add more issues :(
        return retrieve_issues($project,$n+1,@xmls);
    }

    $xml = shift @xmls;
    if (@xmls >= 1) {
        if (0) {
	        # here's a terrible hack
	        # convert the XML to text and jam it before </feed>
	        my @nodes = ();
	        foreach my $feed (@xmls) {
	            my $xp = XML::XPath->new( xml => $xml );
	            my @newnodes = $xp->find('/feed/entry')->get_nodelist;
	            push @nodes, @newnodes;
	        }
	        my @nodexml = map { XML::XPath::XMLParser::as_string($_) } @nodes;
	        my $newxml = join($/, @nodexml);
	
	        # drop the last feed
	        $xml =~ s/<\/feed>//;
	        $xml .= $newxml;
	        $xml .= "$/</feed>$/";
        }
        my $parser = new XML::DOM::Parser;
        my $maindoc = $parser->parse( $xml );
        my @docs = map { $parser->parse( $_ ) } @xmls;
        my @nodes = ();
        foreach my $doc (@docs) {
            my @newnodes = $doc->getElementsByTagName ("entry");
            push @nodes, @newnodes;
            warn "have nodes:".scalar(@nodes);
        }
        my $feed = $maindoc->getElementsByTagName ("feed")->[0];
        foreach my $node (@nodes) {
            #$feed->appendChild( $node );
            #$maindoc->importNode($node);
            my $cnode = $node->cloneNode(1);
            $cnode->setOwnerDocument( $maindoc );
            $feed->appendChild( $cnode );
        }
        warn "Serializing xml";
        $xml = $maindoc->toString();
        save($issuesfilename,$xml);
        return $xml;

    }
    save($issuesfilename,$xml);
    return $xml;
}
