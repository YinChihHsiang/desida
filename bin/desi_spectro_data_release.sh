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
    echo "Prepare raw data (DESI_SPECTRO_DATA) for release."
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
if [[ -z "${DESI_SPECTRO_DATA}" ]]; then
    echo "ERROR: DESI_SPECTRO_DATA is undefined!"
    exit 1
fi
redo=${SCRATCH}/redo_nights.txt
[[ -f ${redo} ]] && /bin/rm -f ${redo}
touch ${redo}
#
# Loop over NIGHT.
#
for night in ${DESI_SPECTRO_DATA}/*; do
    n=$(basename ${night})
    if [[ ${n} < 20210514 || \
          ${n} == 20210517 || \
          ${n} == 20210518 || \
          ${n} == 20210521 || \
          ${n} == 20210529 || \
          ${n} == 20210610 ]]; then
        echo "INFO: Processing night=${n}."
        for expid in ${DESI_SPECTRO_DATA}/${n}/*; do
            e=$(basename ${expid})
            ${verbose} && echo "DEBUG: Processing expid=${e}."
            c=checksum-${e}.sha256sum
            if [[ -f ${expid}/${c} ]]; then
                ${verbose} && echo "DEBUG: ${expid}/${c} exists."
            elif [[ -f ${expid}/checksum-${n}-${e}.sha256sum ]]; then
                c=checksum-${n}-${e}.sha256sum
                ${verbose} && echo "DEBUG: ${expid}/checksum-${c}.sha256sum exists."
            else
                echo "WARNING: ${expid} has no checksum file!"
                ${verbose} && echo "DEBUG: echo ${n} >> ${redo}"
                ${verbose} && echo "DEBUG: (cd ${expid} && sha256sum * > ${SCRATCH}/${c} && unlock_and_move ${c})"
            fi
            ${verbose} && echo "DEBUG: (cd ${expid} && validate ${c})"
            ${test}    || (cd ${expid} && validate ${c})
            if [[ $? != 0 ]]; then
                echo "WARNING: Error detected for ${expid}/${c}!"
                ${verbose} && echo "DEBUG: echo ${n} >> ${redo}"
            fi
        done
    fi
done
#
# Redo backups of changed nights
#
for n in $(cat ${redo} | sort -n | uniq); do
    echo "htar -cvf desi/spectro/data/desi_spectro_data_${n}.tar -H crc:verify=all ${n}"
done
#
# verify checksums for each expid
# if any checksum changes, redo backups
# Double-check permissions.
# Move night.
