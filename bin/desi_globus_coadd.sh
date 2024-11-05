#!/bin/bash
#
# Download files in a specprod with Globus.
#
# Help message.
#
function usage() {
    local execName=$(basename $0)
    (
    echo "${execName} [-h] SPECPROD"
    echo ""
    echo "Download files in a specprod with Globus."
    echo ""
    echo "    -h        = Print this message and exit."
    echo ""
    echo "    SPECPROD  = Spectroscopic Production run name, e.g. 'fuji'."
    ) >&2
}
#
# Options.
#
release=edr
desi_public=6b4e1f6a-e600-11ed-9b9b-c9bb788c490e
my_endpoint=123456
my_endpoint_root=/my_endpoint_home
inventory=${HOME}/Documents/Data/desi/public/${release}/spectro/redux/${specprod}/inventory-${specprod}.txt
batch=batch-${specprod}-coadd
while getopts h argname; do
    case ${argname} in
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done
shift $((OPTIND-1))
if (( $# < 1 )); then
    echo "ERROR: SPECPROD is required!" >&2
    exit 1
fi
specprod=$1
#
# Helper files.
#
[[ -f ${inventory} ]] || \
    wget -O ${inventory} https://data.desi.lbl.gov/public/${release}/spectro/redux/${specprod}/inventory-${specprod}.txt
[[ -f ${batch}.txt ]] && rm -f ${batch}.txt
#
# Create batch file.
#
grep -E '^\./(healpix|tiles/cumulative)/.+/coadd.+\.fits$' ${inventory} | \
    sed -r -e "s%^\./(healpix)/([^/]+)/([^/]+)/([0-9]+)/([0-9]+)/(coadd-[^-]+-[^-]+-[0-9]+\.fits)%/${release}/spectro/redux/${specprod}/\1/\2/\3/\4/\5/\6 ${my_endpoint_root}/${release}/spectro/redux/${specprod}/\1/\2/\3/\4/\5/\6%g" \
        -e "s%^\./(tiles)/(cumulative)/([0-9]+)/([0-9]+)/(coadd-[0-9]+-[0-9]+-thru[0-9]+\.fits)%/${release}/spectro/redux/${specprod}/\1/\2/\3/\4/\5 ${my_endpoint_root}/${release}/spectro/redux/${specprod}/\1/\2/\3/\4/\5%g" > ${batch}.txt
#
# Globus command.
#
echo globus transfer --batch ${batch}.txt --preserve-mtime --label "${batch}" ${desi_public} ${my_endpoint}
