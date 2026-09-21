config_path=config/index.json
db_user=root
db_passwd=HyfjY_jyfhg77
db_name=parser6

mysql -u"${db_user}" -p"${db_passwd}" -N "${db_name}"\
	-e 'SELECT `h1`.`name` FROM `host` AS `h1` WHERE (`h1`.`is_active` = 1) AND (`h1`.`realm` = \'buy\');'\
	| "parallel" -j 5 "./bin/cron/import.pl" "${config_path}"

mysql -u"${db_user}" -p"${db_passwd}" -N "${db_name}"\
	-e 'SELECT `h1`.`name` FROM `host` AS `h1` WHERE (`h1`.`is_active` = 1) AND (`h1`.`realm` = \'sell\');'\
	| parallel -j 0 "./bin/cron/{}.pl" "${config_path}" '2>' /dev/null

./bin/cron/check.sh
./bin/cron/analyze.pl config/index.json
./bin/cron/erase.pl config/index.json
./bin/cron/fts_update.pl config/index.json