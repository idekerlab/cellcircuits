package CCDB::Driver;

our $VERSION = '1.0';

use strict;
use warnings;

use CCDB::QueryInput;
use CCDB::Constants qw($DEBUG $DEFAULT_ENRICHMENT_LIMIT 
		       $pubInfo
		       $species_abbrev);



sub process_query
{
    my ($query) = @_;

    my $qi = CCDB::QueryInput->new();

    $qi->queryString($query);

    $query  =~ s/^\s+//; #strip out leading white space
    $query  =~ s/\s+$//; #strip out trailing white space
    
    my @dbl_quotations = ();
    if(@dbl_quotations = $query =~ /\"/g) {
	my $num_dbl_quots = scalar(@dbl_quotations);
	unless( ($num_dbl_quots % 2) == 0) {
	    return;
	    #this returns undef in scalar context, empty list in list context
	    # - so we can test for this return value for simple error handling
	    #for more complex error handling, see page 391-2 in Cookbook
	}
    }

    ## the ? is necessary after the .+ in the regex because we want minimal 
    ## matching here
    ## EXAMPLE: 
    ##    if there is a query like "DNA binding" gcn4 "amine biosynthesis"
    ## then (\".+\") would match the entire thing, giving a $1 of 
    ## "DNA binding" gcn4 "amine biosynthesis"
    ## instead, the (\".+?\") gives a $1 of "DNA binding" on the first 
    ## iteration and a $1 of "amine biosynthesis" on the second iteration, 
    ## as expected
    while($query =~ /(\".+?\")/)
    {
	$qi->termName()->{$1}++;
	$query =~ s/$1//;
    }
    
    $query  =~ s/^\s+//; #strip out leading white space
    $query  =~ s/\s+$//; #strip out trailing white space
    my @ql = split(/\s+/, $query);

    #my $qh = {};
    #for my $q (@ql){ $qh->{$q}++; }
    
    foreach my $q (@ql)
    {
	if($q =~ /^GO:\d{7}/) { $qi->termAccession()->{$q}++; }
	elsif($q =~ /^MODEL_ID:(\d+)/)  { $qi->modelId()->{$1} = undef; }
	elsif($q =~ /^MODELS_LIKE:(\d+)/)  { $qi->modelLike()->{$1}++; }
	else                    { $qi->gene()->{$q}++;  }
    }

    ## uncomment to debug parsing 
    if($DEBUG) {
	print STDERR $qi->print();
    }
    #exit;

    return ($qi);
}


sub search
{
    my ($queryInput,
	$publications,
	$species,
	$sort_method,
	$pval_thresh,
	$page
	) = @_;

    my $hash               = {};
    my $n_matched_models   = 0;
    my $gid_by_gene_symbol = {};
    my $error_msg          = {};

    if(scalar(keys %{ $publications }) == 0) {
	map { $publications->{$_} = 1 } keys %{$pubInfo};
    }
    if(scalar(keys %{ $species }) == 0) {
	map { $species->{$_} = 1 } keys %{$species_abbrev};
    }
    
     #printf STDERR "Before fetching models: %s\n", localtime(time);
    ($hash, 
     $n_matched_models,
     $error_msg,         # error_msg->{msg-type}{query} = "error/notice..."
     $gid_by_gene_symbol
     ) = CCDB::Query::getMatchingModels($queryInput,
					$publications, #ref-to-hash
					$species,      #ref-to-hash
					$pval_thresh,   #num
					$DEFAULT_ENRICHMENT_LIMIT
					);
    #printf STDERR "After fetching models: %s\n", localtime(time);

    inspect_results($hash, 0) if($DEBUG);
    
    #exit;
    
    if($n_matched_models <= 0) {
	$error_msg->{'no-results'}++;
	#print STDERR "ERROR: no models matched\n";
	CCDB::HtmlRoutines::outputErrorPage($queryInput,        #str
					    $publications, #ref-to-hash
					    $species,      #ref-to-hash
					    $sort_method,  #str
					    $pval_thresh,  #num
					    $error_msg
					    );
    }
    else {

	CCDB::HtmlRoutines::outputResultsPage($queryInput,
					      $publications,
					      $species,
					      $sort_method,
					      $pval_thresh,
					      $page,
					      $hash,
					      $n_matched_models,
					      $error_msg,
					      #$request_URI,
					      $gid_by_gene_symbol
					      );
      }
    
}

sub inspect_results
{
    my ($hash,$flag) = @_;

    if($flag eq 'verbose') {
	foreach my $model_id (keys %{ $hash }){
	    my $pub        = $hash->{$model_id}{"model"}->pub();
	    my $sif        = $hash->{$model_id}{"model"}->sif();
	    my $thm_img    = $hash->{$model_id}{"model"}->thm_img();
	    my $lrg_img    = $hash->{$model_id}{"model"}->lrg_img();
	    my $legend     = $hash->{$model_id}{"model"}->legend();
	    
	    output( "\n\n" );
	    output( "mid     : $model_id");
	    output( "pub     : $pub");
	    output( "sif     : $sif");
	    output( "thm     : $thm_img");
	    output( "lrg     : $lrg_img");
	    output( "legend  : $legend");
	    
	    foreach my $eo (@{ $hash->{$model_id}{"enrichment"} }){
		my $id                         = $eo->id();
		my $n_genes_in_model_with_term = $eo->n_genes_in_model_with_term();
		my $n_genes_in_model           = $eo->n_genes_in_model();
		my $n_genes_with_term          = $eo->n_genes_with_term();
		my $n_genes_in_GO              = $eo->n_genes_in_GO();
		my $pval                       = $eo->pval();
		my $gene_ids                   = $eo->gene_ids();
		my $mid                        = $eo->mid();
		my $mpub                       = $eo->mpub();
		my $mname                      = $eo->mname();
		my $sid                        = $eo->sid();
		my $genus                      = $eo->genus();
		my $species                    = $eo->species();
		my $tid                        = $eo->tid();
		my $tacc                       = $eo->tacc();
		my $tname                      = $eo->tname();
		my $ttype                      = $eo->ttype();
		
		output( "\tid                         : $id");
		output( "\tn_genes_in_model_with_term : "
		    . "$n_genes_in_model_with_term");
		output( "\tn_genes_in_model           : $n_genes_in_model");
		output( "\tn_genes_with_term          : $n_genes_with_term");
		output( "\tn_genes_in_GO              : $n_genes_in_GO");
		output( "\tpval                       : $pval");
		output( "\tgene_ids                   : $gene_ids");
		output( "\tmid                        : $mid");
		output( "\tmpub                       : $mpub");
		output( "\tmname                      : $mname");
		output( "\tsid                        : $sid");
		output( "\tgenus                      : $genus");
		output( "\tspecies                    : $species");
		output( "\ttid                        : $tid");
		output( "\ttacc                       : $tacc");
		output( "\ttname                      : $tname");
		output( "\tttype                      : $ttype\n");
	    }
	    if(exists $hash->{$model_id}{"unannotated-genes"}) {
		output( "#" x 50,);
		output( "unannotated-genes:");
		foreach my $sid (keys %{ $hash->{$model_id}
					 {"unannotated-genes"} }) {
		    foreach my $gid (keys %{ $hash->{$model_id}
					     {"unannotated-genes"}{$sid} }) {
			output( "\tsid: $sid\tgid: $gid");
		    }
		}
		output( "#" x 50);
	    }
	}
    }
    else {
	foreach my $mid (keys %{ $hash }) {
	    if(exists $hash->{$mid}{'enrichment'}) {
		outputf( "mid: $mid\t# enrichment objects = %d\n",
			 scalar(@{ $hash->{$mid}{'enrichment'} }));
	    }
	    else {
		output( "hash->{$mid}{'enrichment'} doesnt exist!");
	    }
	}
	outputf( "n_matched_models: %d\n", scalar(keys %{ $hash }));

    }
    return;
}

sub output
{
    print STDERR @_, "\n";
}


sub outputf
{
    printf STDERR @_;
}


1;
