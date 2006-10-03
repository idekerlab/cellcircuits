#! /usr/bin/perl

my $dir_prefix = "/var/www/html/search/data";
my $hyper_p    = "/cellar/users/cworkman/src/hypergeometric_Pvalue/hyper_p";
my $genes_beneath_terms_FILE = "n_genes_beneath_BY_GO_term_accession.tab";

my $usage=<<USG;
 usage: $0 <db-name> <$genes_beneath_terms_FILE> <pub-dir-name>+

  This program operates on gl files in:

    $dir_prefix/pub-dir-name/gl/*.gl

  What is a gl file?
    -A file with one gene per line, one file per model.
    -At the top of the file is some pertinent summary information prefixed 
    with \#.
    -Following this \#-prefixed preamble is the list of genes in the model, 
    one gene per line.
    -If there is more than one organism\'s genes represented
    in the model, then the organisms genes will be separated by |

    e.g.

  line1:#sif= ...
  line2:#Saccharomyces cerevisiae|Drosophila melanogaster
  line3:#...
  line4:#...
  line5:GCN4|CG12345
  line6:GAL4|CG67890
    ...
  where the 'line:' is not actually included in the real file, but is
    included here to more clearly illustrate the format.

USG
die $usage if(@ARGV < 3);

use DBI;

my $db = shift @ARGV;
my $genes_beneath_terms_FILE = shift @ARGV;
map { $pub_dir_names->{$_}++; } @ARGV;

my $server   = 'localhost';
my $username = 'mdaly';
my $password = 'mdalysql';
my $dbh = DBI->connect("dbi:mysql:$db", $username, $password);

my $get_species_id = qq{
SELECT species.id
FROM   species
WHERE  species.genus=? AND species.species=?
};
my $get_species_id_STH = $dbh->prepare($get_species_id);

my $get_terms_of_gene_symbol = qq{
SELECT DISTINCT
 gene_product.id     as gene_product_id,
 gene_product.symbol as symbol,
 term.acc            as term_acc,
 term.name           as term_name,
 term.term_type      as term_type,
 species.genus       as genus,
 species.species     as species
FROM gene_product, association, graph_path, term, species
WHERE
 gene_product.species_id     = species.id AND
 association.gene_product_id = gene_product.id AND
 graph_path.term2_id         = association.term_id AND
 graph_path.term1_id         = term.id AND
 species.genus               = ? AND
 species.species             = ? AND
 gene_product.symbol         = ?
};
my $get_terms_of_gene_symbol_STH = $dbh->prepare($get_terms_of_gene_symbol);

my $get_terms_of_gene_synonym = qq{
SELECT DISTINCT
 gene_product.id                      as gene_product_id,
 gene_product.symbol                  as symbol,
 gene_product_synonym.product_synonym as synonym,
 term.acc                             as term_acc,
 term.name                            as term_name,
 term.term_type                       as term_type,
 species.genus                        as genus,
 species.species                      as species
FROM gene_product, gene_product_synonym, association, graph_path, term, species
WHERE
 gene_product_synonym.gene_product_id = gene_product.id AND
 gene_product.species_id              = species.id AND
 association.gene_product_id          = gene_product.id AND
 graph_path.term2_id                  = association.term_id AND
 graph_path.term1_id                  = term.id AND
 species.genus                        = ? AND
 species.species                      = ? AND
 gene_product_synonym.product_synonym = ?
};
my $get_terms_of_gene_synonym_STH = $dbh->prepare($get_terms_of_gene_synonym);

my $get_ancestors_of_term = qq{
SELECT
 p.name      as term_name,
 p.acc       as term_acc,
 p.term_type as term_type
FROM
 graph_path as g
  INNER JOIN
 term AS t ON (t.id = g.term2_id)
  INNER JOIN
 term AS p ON (p.id = g.term1_id)
  INNER JOIN
 term2term AS r ON (r.term2_id = p.id)
WHERE
 g.distance > 0 AND
 t.acc = ?
};
my $get_ancestors_of_term_STH = $dbh->prepare($get_ancestors_of_term);

my $get_tacc_from_tname = qq{
SELECT acc FROM term WHERE name = ?
};
my $get_tacc_from_tname_STH = $dbh->prepare($get_tacc_from_tname);

my @root_term_names = qw(
			 biological_process
			 cellular_component
			 molecular_function
			 );

foreach my $rtn (@root_term_names){
    $get_tacc_from_tname_STH->bind_param(1,$rtn,{TYPE=>12});
    $get_tacc_from_tname_STH->execute();
    my $tacc;
    my $row = $get_tacc_from_tname_STH->fetchrow_arrayref();
    if(scalar(@$row) > 1){ 
	print STDERR "ERROR: more than term.acc corresponds "
	    . "to term.name = $rtn\n";  exit;
    }
    elsif(scalar(@$row) == 0){ 
	print STDERR "ERROR: no term.acc corresponds "
	    . "to term.name = $rtn\n"; exit;
    }
    else{ 
	$tacc = $row->[0]; 
	$acc_by_type->{$rtn} = $tacc;
	print "acc_by_type->{$rtn} : $acc_by_type->{$rtn}\n";
    }
}

@outfile_data_fields = qw(
			 pval
			 n_genes_in_model_with_term
			 n_genes_in_model
			 n_genes_with_term
			 n_genes_in_GO 
			 species_id
			 genus
			 species
			 term_acc
			 term_type
			 term_name
			 genes_in_model_with_term
			 );

print "genes_beneath_terms_FILE: $genes_beneath_terms_FILE\n";

my $org_acc_n_genes_beneath = read_genes_beneath_file($genes_beneath_terms_FILE);

#my $org_acc_n_genes_beneath = read_genes_beneath_file($genes_beneath_terms_FILE);
#foreach my $k1 (keys %{ $org_acc_n_genes_beneath }){
#    foreach my $k2 (keys %{ $org_acc_n_genes_beneath->{$k1} }){
#	print "org_acc_n_genes_beneath->{$k1}{$k2} : $org_acc_n_genes_beneath->{$k1}{$k2}\n" 
#	    if($org_acc_n_genes_beneath->{$k1}{$k2} < 1);
#    }
#}
#exit;

$cwd = `pwd`; chomp $cwd;
print "cwd = $cwd\n";
my $count = 0;
foreach my $pub_dir_name (sort keys %{ $pub_dir_names }) {
    my @dp = split(/\//,$pub_dir_name);
    my $pub = shift @dp;
    my $gl_dir = "";
    if(scalar(@dp)>=1){
	my $path = join "/", @dp;
	$gl_dir = "$dir_prefix/$pub/gl/$path";
    }
    else{ $gl_dir = "$dir_prefix/$pub/gl"; }

    chdir "$gl_dir" or die "Cannot cd to $gl_dir: $!\n";
    my @gl_files = split "\n", `ls *.gl`;

    my $pub_dir_str = join ".", $pub,@dp;
    #my $missing_gene_errorlog = "$cwd/missing_gene_errorlog.$pub.$$";
    #if(-e $missing_gene_errorlog){
#	open(MISSING, ">> $missing_gene_errorlog") 
#	    or die "Cannot open $missing_gene_errorlog: $!\n";
#    }
#    else{
#	open(MISSING, "> $missing_gene_errorlog") 
#	    or die "Cannot open $missing_gene_errorlog: $!\n";
#    }
    
    #my @gl_files = ();
    #push @gl_files, "variant35.gl";
    for my $gl_file (@gl_files) {
	my $gl_file_path = "$gl_dir/$gl_file";
	my ($genes) = parse_gl_file($gl_file_path); #genes->{organism}{gene_name}

	$count++;
	print STDERR "$count\t$pub_dir_name\t$gl_file\n";
	
	my $results_file = "$cwd/results/$pub_dir_name/${gl_file}.enrichment";
	#my $res_file_name = join "_", "$pub_dir_str", "${gl_file}.enrichment";
	#my $results_file  = "$cwd/results/enrichment-files/$res_file_name";
	open(RESULTS, "> $results_file") or die "Cannot open $results_file: $!\n";
	
	my $n_genes_in_model = 0;
	foreach my $org (sort keys %{ $genes }) {
	    my($genus,$species) = split(/\s/, $org);
	    my $species_id = get_species_id($genus,$species);
	    
	    my ($genes_in_model,#ref-to-hash genes_in_model->{gene_product_id} = symbol
		$org_tacc_gid,  #org_tacc_gid->{org}{tacc}{gene_name}++
		$org_tacc       #org_tacc->{org}{tacc} = "ttype\ttname"
		) = get_terms_annotated_to_genes($genes,$org,$genus,$species,
						 \*RESULTS,$gl_file);
	    $n_genes_in_model = scalar(keys %{ $genes_in_model });

	    #printf "%s\n", join "\t", @outfile_data_fields;
	    printf RESULTS "%s\n", join "\t", @outfile_data_fields;

	    foreach my $tacc (keys %{ $org_tacc_gid->{$org} }){
		my @genes_in_model_with_term = keys %{ $org_tacc_gid->{$org}{$tacc} };
		my $n_genes_in_model_with_term = scalar(@genes_in_model_with_term);

###### FILTER OUT IF OVERLAP IS <= 1 RIGHT HERE #######	    
		#if($n_genes_in_model_with_term > 1) {
		my ($ttype,$tname) = split(/\t/,$org_tacc->{$org}{$tacc});
		my $n_genes_in_GO = 
		    $org_acc_n_genes_beneath->{$org}{$acc_by_type->{$ttype}};
		my $n_genes_with_term = $org_acc_n_genes_beneath->{$org}{$tacc};
		
		my $hyperp_input = 
		    join " ", $n_genes_in_model_with_term, $n_genes_in_model,
		    $n_genes_with_term, $n_genes_in_GO;
		
		my $pval = `$hyper_p $hyperp_input\n`; chomp $pval;
		$pval = sprintf("%0.6e", $pval);
		
		#printf STDERR "$pval\t$n_genes_in_model_with_term\t"
		#    . "$n_genes_in_model\t$n_genes_with_term\t"
		#    . "$n_genes_in_GO\t$species_id\t$genus\t$species\t"
		#    . "$tacc\t$ttype\t\"$tname\"\t"
		#    . "%s\n", join "\t", sort @genes_in_model_with_term;
		printf RESULTS "$pval\t$n_genes_in_model_with_term\t"
		    . "$n_genes_in_model\t$n_genes_with_term\t"
		    . "$n_genes_in_GO\t$species_id\t$genus\t$species\t"
		    . "$tacc\t$ttype\t\"$tname\"\t"
		    . "%s\n", join "\t", sort @genes_in_model_with_term;
		
	    }
	}
	close(RESULTS);
    }
    #close(MISSING);
}

sub get_terms_annotated_to_genes
{
    my ($gene_list,$organism,$genus,$species,$ofh,$gl_name) = @_;

    my $genes_in_model = {}; #genes_in_model->{gene_product_id} = symbol
    my $org_tacc_gid = {};   #org_tacc_gid->{org}{tacc}{gid}++
    my $org_tacc = {};       #org_tacc->{org}{tacc} = "ttype\ttname"
    foreach my $gene (keys %{ $gene_list->{$organism} }) {
	my $tmp_terms = {};
	($tmp_terms,$genes_in_model) = get_terms($gene,$genus,$species,
						 $genes_in_model,$ofh,$gl_name);
	$tmp_terms = get_ancestors($tmp_terms);

	foreach my $ttype (keys %{ $tmp_terms }){
	    foreach my $tacc (keys %{ $tmp_terms->{$ttype} }) {
		$org_tacc_gid->{$organism}{$tacc}{$gene}++;
		$org_tacc->{$organism}{$tacc} = "$ttype\t$tmp_terms->{$ttype}{$tacc}";
	    }
	}
    }

    return ($genes_in_model, $org_tacc_gid, $org_tacc);
}

sub get_terms
{
    my ($gene,$genus,$species,$genes_in_model,$ofh,$gl_name) = @_;

#### CLOOGE!!!  ADDS _HUMAN ONTO END OF ALL HUMAN GENES!!! ####
    if(($genus=~/homo/i) && ($species=~/sapiens/i)){ $gene .= "_HUMAN"; }

    $get_terms_of_gene_symbol_STH->bind_param(1, $genus,   {TYPE=>12});
    $get_terms_of_gene_symbol_STH->bind_param(2, $species, {TYPE=>12});
    $get_terms_of_gene_symbol_STH->bind_param(3, $gene,    {TYPE=>12});
    $get_terms_of_gene_symbol_STH->execute();

    my $tmp_terms = {};
    while(my $Ref = $get_terms_of_gene_symbol_STH->fetchrow_hashref()) {
	next if($Ref->{term_name} eq 'all');
	unless($tmp_terms->{ $Ref->{term_type} }{ $Ref->{term_acc} }) {
	    $tmp_terms->{ $Ref->{term_type} }{ $Ref->{term_acc} } = $Ref->{term_name};
	}
	unless(exists $genes_in_model->{ $Ref->{gene_product_id} }) {
	    $genes_in_model->{ $Ref->{gene_product_id} } = $Ref->{symbol};
	}
    }

    if(scalar(keys %{ $tmp_terms }) == 0){
	$get_terms_of_gene_synonym_STH->bind_param(1, $genus,   {TYPE=>12});
	$get_terms_of_gene_synonym_STH->bind_param(2, $species, {TYPE=>12});
	$get_terms_of_gene_synonym_STH->bind_param(3, $gene,    {TYPE=>12});
	$get_terms_of_gene_synonym_STH->execute();
	my $synonyms = {};
	while(my $Ref = $get_terms_of_gene_synonym_STH->fetchrow_hashref()) {
	    next if($Ref->{term_name} eq 'all');
	    unless($tmp_terms->{ $Ref->{term_type} }{ $Ref->{term_acc} }) {
		$tmp_terms->{ $Ref->{term_type} }{ $Ref->{term_acc} } = $Ref->{term_name};
	    }
	    unless(exists $genes_in_model->{ $Ref->{gene_product_id} }) {
		$genes_in_model->{ $Ref->{gene_product_id} } = $Ref->{symbol};
		$synonyms->{$gene} = $Ref->{symbol};
	    }
	}
	if(scalar(keys %{ $tmp_terms }) > 0){
	    print $ofh "#USING $synonyms->{$gene} instead of its synonym "
		. "$gene in $genus $species\n";
	}
	elsif(scalar(keys %{ $tmp_terms }) == 0){
	    print $ofh    "#NOT FOUND: $gene in $genus $species\n";
	    #print MISSING "#NOT FOUND: $gl_name: $gene in $genus $species\n";
	}
    }

    return ($tmp_terms,$genes_in_model);
}

sub get_ancestors
{
    my ($terms) = @_;

    foreach my $ttype (keys %{ $terms }){
	foreach my $tacc (keys %{ $terms->{$ttype} }) {
	    $get_ancestors_of_term_STH->bind_param(1, $tacc, {TYPE=>12});
	    $get_ancestors_of_term_STH->execute();
	    while(my $Ref = $get_ancestors_of_term_STH->fetchrow_hashref) {
		next if($Ref->{term_name} eq 'all');
		unless(exists $terms->{$Ref->{term_type}}{ $Ref->{term_acc} }) {
		    $terms->{$Ref->{term_type}}{ $Ref->{term_acc} } = $Ref->{term_name};
		}	    
	    }
	}
    }
    return $terms;
}

sub get_species_id
{
    my ($genus,$species) = @_;

    $get_species_id_STH->bind_param(1, $genus,   {TYPE=>12});
    $get_species_id_STH->bind_param(2, $species, {TYPE=>12});
    $get_species_id_STH->execute();

    my $species_id;
    my $row = $get_species_id_STH->fetchrow_arrayref();
    if(scalar(@$row) > 1){ 
	print STDERR "ERROR: more than one species id corresponds "
	    . "to genus=$genus species=$species\n";  exit;
    }
    elsif(scalar(@$row) == 0){ 
	print STDERR "ERROR: no species id corresponds "
	    . "to genus=$genus species=$species\n"; exit;
    }
    else{ $species_id = $row->[0]; }

    return $species_id;
}

sub parse_gl_file
{
    my ($f) = @_;

    my $genes = {};
    my @orgs = ();
    my $n_org;
    open(F, "$f") or die "Cannot open $f: $!\n";
    while(<F>){
	chomp;
	if(/^\#/){
	    next if($. != 2);
	    s/^\#//;
	    @orgs=split(/\|/);
	    $n_org = scalar(@orgs);
	    next;
	}
	if($n_org > 1){
	    my @l=split(/\|/);
	    for my $i (0..$#l){
		$genes->{$orgs[$i]}{$l[$i]}++;
	    }
	}
	elsif($n_org == 1){ $genes->{$orgs[0]}{$_}++; }
	else{ print STDERR "ERROR in readGeneList().  n_org <= 0\n"; exit; }
    }
    close(F);
    
    return $genes;
}

sub read_genes_beneath_file
{
    my($file) = @_;
    my $org_acc_n_genes_beneath = {};

    open(FILE, "< $file") or die "Cannot open $file: $!\n";
    while(<FILE>){
	chomp;
	my ($acc,$n_genes_beneath,$org) = split(/\t/,$_);
	unless($n_genes_beneath == 0){
	    $org_acc_n_genes_beneath->{$org}{$acc} = $n_genes_beneath;
	}
    }
    close(FILE);

    return $org_acc_n_genes_beneath;
}
