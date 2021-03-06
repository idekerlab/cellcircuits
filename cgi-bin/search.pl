#!/usr/bin/perl
use strict;
use warnings;

#
# Set PERL5LIB environment variable instead of 
# hardcoding this path.
#
# In Apache httpd.conf:
# SetEnvIf Request_URI "search" PERL5LIB /var/www/cgi-bin/search/v1.0
# NOT USING SetEnvIf (encountered some apache config problems)

use lib '/var/www/cgi-bin/search/v1.0';

use CCDB::QueryInput;
use CCDB::Driver;
use CCDB::Query;
use CCDB::Model;
use CCDB::HtmlRoutines;
use CGI::Carp qw(fatalsToBrowser); 
use CGI qw(:standard);

my $publications = {};
my $species      = {};
my $sort_method  = '';
my $page         = 1;
my $pval_thresh  = 1e-4;
my $error_msg    = {};

print "Content-type: text/html\n\n";
if(param("search_query"))
{
    my $query        = param("search_query");
    my @pubs         = param("publication");
    my @orgs         = param("species");
    my $sort_method  = param("sort_method");
    my $pval_thresh  = param("pval_thresh");

    my @qs = split(/;/, query_string()); #query_string is a CGI.pm method
    #printf "query_string: %s", join "<br>", @qs;

    for my $sp  (@orgs) {
	$species->{$sp}++; #print "species->{$sp}<br>";
    }
    for my $pub (@pubs) {
	$publications->{$pub}++; #print "publications->{$pub}<br>";
    }

    my $queryInput = CCDB::Driver::process_query($query);
    if(!defined($queryInput)) {
	$error_msg->{'uneven-number-of-double-quotes'}++;
	CCDB::HtmlRoutines::outputErrorPage($query, 
					    $publications,
					    $species,
					    $sort_method,
					    $pval_thresh,
					    $error_msg);
	exit;
    }

    if(param("search_query_button"))
    {
	$page = 1;
    }
    elsif(param("page") && param("page") =~ /^\d+$/)
    {
	$page = param("page");
    }
    else
    {
	$page = 1;
    }

    if($pval_thresh > 1)     { $pval_thresh = 1; }
    elsif($pval_thresh <= 0) { $pval_thresh = 1; }

    CCDB::Driver::search($queryInput,
			 $publications,
			 $species,
			 $sort_method,
			 $pval_thresh,
			 $page);

}
else {
    $error_msg->{'no-query-notice'}++;
    CCDB::HtmlRoutines::outputErrorPage("", 
					$publications,
					$species,
					$sort_method,
					$pval_thresh,
					$error_msg);
}
