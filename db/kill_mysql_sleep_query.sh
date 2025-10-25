USER=root
sleep_query_id=$(mysql -u mysqladmin -h 10.224.3.100 -p'P0VFId6T@SaatdvKHt8UkKHM' -e "show processlist" | awk '/Sleep/ {print $1}')
for i in $sleep_query_id; do
                mysql -u mysqladmin -h 10.224.3.100 -p'P0VFId6T@SaatdvKHt8UkKHM' -e "KILL $i;"; done