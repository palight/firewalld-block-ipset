#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

# Get script root directory, solution courtesy of Dave Dopson via (https://stackoverflow.com/a/246128)
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  SCRIPT_DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPT_DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

## Setup Firewalld
firewall-cmd --permanent --zone=drop --remove-source=ipset:blocklist_v4
firewall-cmd --permanent --zone=drop --remove-source=ipset:blocklist_v6
firewall-cmd --reload
firewall-cmd --permanent --delete-ipset=blocklist_v4
firewall-cmd --permanent --delete-ipset=blocklist_v6
firewall-cmd --reload
firewall-cmd --permanent --new-ipset=blocklist_v4 --type=hash:net --option=family=inet --option=hashsize=4096 --option=maxelem=200000
firewall-cmd --permanent --new-ipset=blocklist_v6 --type=hash:net --option=family=inet6 --option=hashsize=4096 --option=maxelem=200000
firewall-cmd --reload

## Get our intelligence (sources from ipdeny.com) and block them!                                                                                                                                                                            ## Note that the following lines will create a 'zones' directory within the $SCRIPT_DIR and populate it with textfiles from ipdeny.com
rm -rfv $SCRIPT_DIR/zones
mkdir -pv $SCRIPT_DIR/zones
cd $SCRIPT_DIR/zones/
for n in $(cat ../index.txt)
do
        wget https://www.ipdeny.com/ipv6/ipaddresses/aggregated/$n-aggregated.zone
        wget https://www.ipdeny.com/ipblocks/data/countries/$n.zone
        echo "bye-bye $n"
        firewall-cmd --permanent --ipset=blocklist_v4 --add-entries-from-file="$n.zone"
        firewall-cmd --permanent --ipset=blocklist_v6 --add-entries-from-file="$n-aggregated.zone"
done

## Re-add the sources back to the drop zone
firewall-cmd --permanent --zone=drop --add-source=ipset:blocklist_v4
firewall-cmd --permanent --zone=drop --add-source=ipset:blocklist_v6

## Reload one last time, and we should have blocked all country-code targets in index.txt
firewall-cmd --reload

echo "---"
echo "Thank you to the folks at ipdeny.com for generating these lists for us to freely utilize."
echo ""
echo "Blocking approx. $(ipset list blocklist_v4 | wc -l) ipv4 target ranges, and approx. $(ipset list blocklist_v6 | wc -l) ipv6 target ranges."
echo "---"
echo ""

exit 0
