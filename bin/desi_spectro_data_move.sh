#!/bin/bash
# Licensed under a 3-clause BSD style license - see LICENSE.rst.
#
if [[ -z "${DESIDA}" ]]; then
    echo "ERROR: DESIDA is undefined!"
    exit 1
fi
source ${DESIDA}/bin/desida_library.sh
#
# Help message.
#
function usage() {
    local execName=$(basename $0)
    (
    echo "${execName} [-h] [-t] [-v] [-V] RELEASE"
    echo ""
    echo "Move raw data files (DESI_SPECTRO_DATA) into place for release."
    echo ""
    echo "Verify checksums, redo tape backups if necessary."
    echo ""
    echo "         -h = Print this message and exit."
    echo "         -t = Test mode.  Do not actually make any changes. Implies -v."
    echo "         -v = Verbose mode. Print extra information."
    echo "         -V = Version.  Print a version string and exit."
    echo "    RELEASE = Name of release, e.g. 'edr'."
    ) >&2
}
#
# Night to release.
#
function is_night_in_release() {
    local release=$1
    local night=$2
    if [[ "${release}" == "edr" ]]; then
        (( ${night} >= 20200201 && ${night} < 20210514 )) && return 0
        (( ${night} == 20210517 || ${night} == 20210518 || ${night} == 20210521 || ${night} == 20210529 || ${night} == 20210610 )) && return 0
    fi
    return 1
}
#
# Get options.
#
test=false
verbose=false
while getopts htvV argname; do
    case ${argname} in
        h) usage; exit 0 ;;
        t) test=true; verbose=true ;;
        v) verbose=true ;;
        V) version; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done
shift $((OPTIND-1))
if [[ $# < 1 ]]; then
    echo "ERROR: RELEASE must be defined on the command-line!"
    exit 1
fi
release=$1
if [[ "${release}" != "edr" ]]; then
    echo "ERROR: Undefined release=${release}!"
    exit 1
fi
if [[ -z "${DESI_SPECTRO_DATA}" ]]; then
    echo "ERROR: DESI_SPECTRO_DATA is undefined!"
    exit 1
fi
#
# Define destination.
#
release_data=${DESI_ROOT}/public/${release}/spectro/data
relative_data='../../public/edr/spectro/data'
for n in ${DESI_SPECTRO_DATA}/20*; do
    night=$(basename ${n})
    if is_night_in_release ${release} ${night}; then
        ${verbose} && echo "DEBUG: mv -v ${DESI_SPECTRO_DATA}/${night} ${release_data}"
        ${test}    || mv -v ${DESI_SPECTRO_DATA}/${night} ${release_data}
        ${verbose} && echo "DEBUG: (cd ${DESI_SPECTRO_DATA} && ln -s -v ${relative_data}/${night})"
        ${test}    || (cd ${DESI_SPECTRO_DATA} && ln -s -v ${relative_data}/${night})
    fi
done
