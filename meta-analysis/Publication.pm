package Publication;

use Object;
use MultiOrganismSIF;

@ISA = qw(Object);

Publication->_generateAccessors(qw(sifOrgMap sifs name dataDir));

sub new
{
    my ($caller, $name, $dataDir, $geneNameMapper, $edgeMapper) = @_;
    my $self = $caller->SUPER::new();

    $self->sifOrgMap({});
    $self->name($name);
    $self->sifs({});
    $self->dataDir(join("/", $dataDir, $name));
    
    if($self->readSifList())
    {
	$self->parseSIFs($geneNameMapper, $edgeMapper);
    }
    return $self;
}

sub readSifList
{
    my ($self) = @_;
    
    my $sif_list = $self->dataDir() . "/sifList";
    open(SIF_LIST, "$sif_list") or die "Cannot open $sif_list: $!\n";
    while(<SIF_LIST>)
    {
        chomp;
        my ($sif, $org_str) = split(/\t/);

	$sif =~ /^\.\/sif\/(.*)/;
	my $file = $1;

        my @orgs = split(/\|/, $org_str);

	$self->sifOrgMap()->{$file} = \@orgs;
     }
     close(SIF_LIST);

    return 1;
}

sub parseSIFs
{
    my ($self, $geneNameMapper, $edgeMapper) = @_;
    my $dir = $self->dataDir();

    my ($file, $orgs, $name);
    while(($file, $orgs) = each(%{$self->sifOrgMap()}))
    {
	my $sif = MultiOrganismSIF->new(join("/", $dir, "sif", $file),
					$orgs,
					$geneNameMapper,
					$edgeMapper);

	if($file =~ /(.*)\.sif$/)
	{
	    $sif->name($1);
	}
	else
	{
	    $sif->name($file);
	}

	$sif->pub($self->name());
	$self->sifs()->{$file} = $sif;
    }
}

sub print
{
    my ($self) = @_;

    my $str = "";
    my $sifs = $self->sifs();
    my ($sifSummary);
    foreach my $file (sort keys %{$self->sifOrgMap()})
    {
	$sifSummary = "";
	if(exists($sifs->{$file}))
	{
	    $sifSummary = $sifs->{$file}->printSummary();
	}
	$str .= sprintf("%s: %s\n", $file, $sifSummary);

    }
    return $str;
}

1;
