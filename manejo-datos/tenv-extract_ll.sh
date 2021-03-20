#/bin/bash!

#Version precaria

a=grep
if [[ $1 =~ \.bz2$ ]]
then 
    a=bzgrep;
else
    if [[ $1 =~ \.bz2$ ]]
    then
        a=xzgrep;
    fi
fi;

b=$(basename $1)

read sit lon e0 e n0 n < <($a -m 1 ${b:0:4} $1 | awk '//{print $1, $7, $8, $9, $10, $11}')

echo -en $sit\ 

cs2cs -f '%.7f' +proj=tmerc +lat_0=0 +lon_0=$lon +datum=WGS84 <<EOF
$(echo $e0 + $e | bc) $(echo $n0 + $n | bc)
EOF
