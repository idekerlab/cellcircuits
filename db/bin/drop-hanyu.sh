#!/bin/bash

PUB=Chuang2007_MSB
DB=cc
OUTPUT=output
DATA=../data

#mysql -v -v -u mdaly --password=mdalysql $DB \
#    -e "delete from gene_model where model_id in (select id from model where pub = '$PUB')"


#mysql -v -v -u mdaly --password=mdalysql $DB \
#    -e "delete from model where pub = '$PUB'"

mysql -v -v -u mdaly --password=mdalysql $DB \
    -e "delete from enrichment where model_id in (select id from model where pub = '$PUB')"
