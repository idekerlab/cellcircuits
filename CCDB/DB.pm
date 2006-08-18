package CCDB::DB;

use strict;
use warnings;

#use lib '/opt/www/cgi-bin/search/v1.6';
use BM::mysql;

my $VERSION = '0.1';
use constant DSN => "DBI:mysql:cc";
use constant USER => "mdaly";
use constant PASSWORD => "mdalysql";



my $types = {
    'gene_product' => {
	'id'                   => 4,
	'symbol'               => 12,
	'dbxref_id'            => 4,
	'species_id'           => 4
	},
    'gene_product_synonym' => {
	'gene_product_id'  => 4,
	'product_synonym'  => 12
	},
    'species' => {
	'id'             => 4,
	'common_name'    => 12,
	'genus'          => 12,
        'species'        => 12
	},
    'model' => { 
	'id'       => 4, 
	'pub'      => 12,
	'name'     => 12
	},
    'gene_model' => {
	'id'       => 4,
	'model_id' => 4,
	'gene_id'  => 4
	}
};

#####################################################################
# getDB - Returns a database handle connection for the database.
# Parameters: None.
# Returns: DBH Connection Handle.
sub getDB {
    my $dbh = DBI->connect(DSN,USER,PASSWORD,{PrintError => 1,RaiseError => 1});
    return $dbh;
}

#####################################################################
# get_pk_value - Returns the most recent auto_increment value for a PK.
# Parameters: Database Handle.
# Returns: Primary key value.
sub get_pk_value {
    my $dbh = shift or die "DB::get_pk_value needs a Database Handle...";

    my $dbd = BM::mysql->new();
    return $dbd->get_pk_value( $dbh );
}

#####################################################################
# getType: Returns the type of a column within a table.
# Parameters: Table name and column name.
# Returns: DBI Type code.
sub getType {
    my $table = shift;
    my $col = shift;
    return $types->{$table}{$col};
}

1;
