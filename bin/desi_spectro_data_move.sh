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
    echo "Run this script after checksums have been re-validated."
    echo ""
    echo "         -h = Print this message and exit."
    echo "         -t = Test mode.  Do not actually make any changes. Implies -v."
    echo "         -v = Verbose mode. Print extra information."
    echo "         -V = Version.  Print a version string and exit."
    echo "    RELEASE = Name of release, e.g. 'edr'."
    ) >&2
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
if [[ "${release}" != "edr" && "${release}" != "dr1" ]]; then
    echo "ERROR: Undefined release=${release}!"
    exit 1
fi
if [[ -z "${DESI_SPECTRO_DATA}" ]]; then
    echo "ERROR: DESI_SPECTRO_DATA is undefined!"
    exit 1
fi
#
# Set up moves on HPSS.
#
hpss_moves=${SCRATCH}/desi_spectro_data_move_hpss.txt
hpss_desi=/nersc/projects/desi
if [[ -f ${hpss_moves} ]]; then
    ${verbose} && echo "DEBUG: /bin/rm -f ${hpss_moves}"
    ${test}    || /bin/rm -f ${hpss_moves}
fi
${verbose} && echo "DEBUG: touch ${hpss_moves}"
${test}    || touch ${hpss_moves}
#
# Define destination.
#
release_data=${DESI_ROOT}/public/${release}/spectro/data
relative_data="../../public/${release}/spectro/data"
for n in ${DESI_SPECTRO_DATA}/20*; do
    night=$(basename ${n})
    if [[ -L ${n} ]]; then
        echo "INFO: ${n} is already a symlink."
    else
        if is_night_in_release ${release} ${night}; then
            ${verbose} && echo "DEBUG: chmod -v u+w ${DESI_SPECTRO_DATA}/${night}"
            ${test}    || chmod -v u+w ${DESI_SPECTRO_DATA}/${night}
            ${verbose} && echo "DEBUG: mv -v ${DESI_SPECTRO_DATA}/${night} ${release_data}"
            ${test}    || mv -v ${DESI_SPECTRO_DATA}/${night} ${release_data}
            ${verbose} && echo "DEBUG: chmod -v u-w ${release_data}/${night}"
            ${test}    || chmod -v u-w ${release_data}/${night}
            ${verbose} && echo "DEBUG: (cd ${DESI_SPECTRO_DATA} && ln -s -v ${relative_data}/${night})"
            ${test}    || (cd ${DESI_SPECTRO_DATA} && ln -s -v ${relative_data}/${night})
            ${verbose} && echo "DEBUG: echo mv ${hpss_desi}/spectro/data/desi_spectro_data_${night}.tar ${hpss_desi}/spectro/data/desi_spectro_data_${night}.tar.idx ${hpss_desi}/public/${release}/spectro/data >> ${hpss_moves}"
            ${test}    || echo "mv ${hpss_desi}/spectro/data/desi_spectro_data_${night}.tar ${hpss_desi}/spectro/data/desi_spectro_data_${night}.tar.idx ${hpss_desi}/public/${release}/spectro/data" >> ${hpss_moves}
        fi
    fi
done
${verbose} && echo "DEBUG: hsi in ${hpss_moves}"
${test}    || hsi in ${hpss_moves}
