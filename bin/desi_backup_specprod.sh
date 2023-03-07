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
    echo "${execName} [-h] [-t] [-v] [-V] SPECPROD"
    echo ""
    echo "Prepare an entire spectroscopic reduction (SPECPROD) for tape backup."
    echo ""
    echo "Assuming files are on disk are in a clean, archival state, this script"
    echo "will create checksum files for the entire data set."
    echo ""
    echo "    -h = Print this message and exit."
    echo "    -t = Test mode.  Do not actually make any changes. Implies -v."
    echo "    -v = Verbose mode. Print extra information."
    echo "    -V = Version.  Print a version string and exit."
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
    echo "ERROR: SPECPROD must be defined on the command-line!"
    exit 1
fi
export SPECPROD=$1
if [[ ! -d ${DESI_SPECTRO_REDUX}/${SPECPROD} ]]; then
    echo "ERROR: ${DESI_SPECTRO_REDUX}/${SPECPROD} does not exist!"
    exit 1
fi
#
# Top-level files
#
home=${DESI_SPECTRO_REDUX}/${SPECPROD}
cd ${home}
if [[ -f redux_${SPECPROD}.sha256sum ]]; then
    if ${test}; then
        echo "INFO: redux_${SPECPROD}.sha256sum already exists."
    else
        if validate redux_${SPECPROD}.sha256sum; then
            ${verbose} && echo "INFO: redux_${SPECPROD}.sha256sum already exists and is valid."
        else
            echo "WARNING: redux_${SPECPROD}.sha256sum is invalid!"
        fi
    fi
else
    ${verbose} && echo "DEBUG: sha256sum exposures-${SPECPROD}.* tiles-${SPECPROD}.* > ${SCRATCH}/redux_${SPECPROD}.sha256sum"
    ${test}    || sha256sum exposures-${SPECPROD}.* tiles-${SPECPROD}.* > ${SCRATCH}/redux_${SPECPROD}.sha256sum
    ${verbose} && echo "DEBUG: unlock_and_move redux_${SPECPROD}.sha256sum"
    ${test}    || unlock_and_move redux_${SPECPROD}.sha256sum
fi
#
# tilepix.* files in healpix directory
#
cd healpix
if [[ -f redux_${SPECPROD}_healpix.sha256sum ]]; then
    if ${test}; then
        echo "INFO: healpix/redux_${SPECPROD}_healpix.sha256sum already exists."
    else
        if validate redux_${SPECPROD}_healpix.sha256sum; then
            ${verbose} && echo "INFO: healpix/redux_${SPECPROD}_healpix.sha256sum already exists and is valid."
        else
            echo "WARNING: healpix/redux_${SPECPROD}_healpix.sha256sum is invalid!"
        fi
    fi
else
    if [[ -f tilepix.fits ]]; then
        ${verbose} && echo "DEBUG: sha256sum tilepix.* > ${SCRATCH}/redux_${SPECPROD}_healpix.sha256sum"
        ${test}    || sha256sum tilepix.* > ${SCRATCH}/redux_${SPECPROD}_healpix.sha256sum
        ${verbose} && echo "DEBUG: unlock_and_move redux_${SPECPROD}_healpix.sha256sum"
        ${test}    || unlock_and_move redux_${SPECPROD}_healpix.sha256sum
    else
        echo "WARNING: healpix/tilepix.* files not generated yet, skipping!"
    fi
fi
cd ..
#
# calibnight, exposure_tables
#
for d in calibnight exposure_tables; do
    cd ${d}
    for night in *; do
        cd ${night}
        if [[ -f redux_${SPECPROD}_${d}_${night}.sha256sum ]]; then
            if ${test}; then
                echo "INFO: ${d}/${night}/redux_${SPECPROD}_${d}_${night}.sha256sum already exists."
            else
                if validate redux_${SPECPROD}_${d}_${night}.sha256sum; then
                    ${verbose} && echo "INFO: ${d}/${night}/redux_${SPECPROD}_${d}_${night}.sha256sum already exists and is valid."
                else
                    echo "WARNING: ${d}/${night}/redux_${SPECPROD}_${d}_${night}.sha256sum is invalid!"
                fi
            fi
        else
            ${verbose} && echo "DEBUG: sha256sum * > ${SCRATCH}/redux_${SPECPROD}_${d}_${night}.sha256sum"
            ${test}    || sha256sum * > ${SCRATCH}/redux_${SPECPROD}_${d}_${night}.sha256sum
            ${verbose} && echo "DEBUG: unlock_and_move redux_${SPECPROD}_${d}_${night}.sha256sum"
            ${test}    || unlock_and_move redux_${SPECPROD}_${d}_${night}.sha256sum
        fi
        cd ..
    done
    cd ..
done
#
# processing_tables, run, zcatalog
#
for d in processing_tables run zcatalog; do
    cd ${d}
    if [[ -f redux_${SPECPROD}_${d}.sha256sum ]]; then
        if ${test}; then
            echo "INFO: ${d}/redux_${SPECPROD}_${d}.sha256sum already exists."
        else
            if validate redux_${SPECPROD}_${d}.sha256sum deep; then
                ${verbose} && echo "INFO: ${d}/redux_${SPECPROD}_${d}.sha256sum already exists and is valid."
            else
                echo "WARNING: ${d}/redux_${SPECPROD}_${d}.sha256sum is invalid!"
            fi
        fi
    else
        if [[ "${d}" == "run" ]]; then
            ${verbose} && echo "DEBUG: find . -type f -exec sha256sum \{\} \; > ${SCRATCH}/redux_${SPECPROD}_${d}.sha256sum"
            ${test}    || find . -type f -exec sha256sum \{\} \; > ${SCRATCH}/redux_${SPECPROD}_${d}.sha256sum
        else
            ${verbose} && echo "DEBUG: sha256sum * > ${SCRATCH}/redux_${SPECPROD}_${d}.sha256sum"
            ${test}    || sha256sum * > ${SCRATCH}/redux_${SPECPROD}_${d}.sha256sum
        fi
        ${verbose} && echo "DEBUG: unlock_and_move redux_${SPECPROD}_${d}.sha256sum"
        ${test}    || unlock_and_move redux_${SPECPROD}_${d}.sha256sum
    fi
    if [[ "${d}" == "zcatalog" && -d ${d}/logs ]]; then
        cd ${d}/logs
        if [[ -f redux_${SPECPROD}_${d}_logs.sha256sum ]]; then
            if ${test}; then
                echo "INFO: ${d}/redux_${SPECPROD}_${d}_logs.sha256sum already exists."
            else
                if validate redux_${SPECPROD}_${d}_logs.sha256sum deep; then
                    ${verbose} && echo "INFO: ${d}/redux_${SPECPROD}_${d}_logs.sha256sum already exists and is valid."
                else
                    echo "WARNING: ${d}/redux_${SPECPROD}_${d}_logs.sha256sum is invalid!"
                fi
            fi
        else
            ${verbose} && echo "DEBUG: sha256sum * > ${SCRATCH}/redux_${SPECPROD}_${d}_logs.sha256sum"
            ${test}    || sha256sum * > ${SCRATCH}/redux_${SPECPROD}_${d}_logs.sha256sum
            ${verbose} && echo "DEBUG: unlock_and_move redux_${SPECPROD}_${d}_logs.sha256sum"
            ${test}    || unlock_and_move redux_${SPECPROD}_${d}_logs.sha256sum
        fi
        cd ..
    fi
    cd ..
done
#
# exposures, preproc
#
for d in exposures preproc; do
    cd ${d}
    for night in *; do
        cd ${night}
        for expid in *; do
            if is_empty ${expid}; then
                echo "INFO: ${d}/${night}/${expid} is empty."
            else
                cd ${expid}
                if [[ -f redux_${SPECPROD}_${d}_${night}_${expid}.sha256sum ]]; then
                    if ${test}; then
                        echo "INFO: ${d}/${night}/${expid}/redux_${SPECPROD}_${d}_${night}_${expid}.sha256sum already exists."
                    else
                        if validate redux_${SPECPROD}_${d}_${night}_${expid}.sha256sum; then
                            ${verbose} && echo "INFO: ${d}/${night}/${expid}/redux_${SPECPROD}_${d}_${night}_${expid}.sha256sum already exists and is valid."
                        else
                            echo "WARNING: ${d}/${night}/${expid}/redux_${SPECPROD}_${d}_${night}_${expid}.sha256sum is invalid!"
                        fi
                    fi
                else
                    ${verbose} && echo "DEBUG: sha256sum * > ${SCRATCH}/redux_${SPECPROD}_${d}_${night}_${expid}.sha256sum"
                    ${test}    || sha256sum * > ${SCRATCH}/redux_${SPECPROD}_${d}_${night}_${expid}.sha256sum
                    ${verbose} && echo "DEBUG: unlock_and_move redux_${SPECPROD}_${d}_${night}_${expid}.sha256sum"
                    ${test}    || unlock_and_move redux_${SPECPROD}_${d}_${night}_${expid}.sha256sum
                fi
                cd ..
            fi
        done
        cd ..
    done
    cd ..
done
#
# healpix, tiles
#
for d in healpix tiles; do
    cd ${d}
    for group in *; do
        if [[ -d ${group} ]]; then
            for dd in $(find ${group} -type d); do
                has_files=$(find ${dd} -maxdepth 1 -type f)
                if [[ -n "${has_files}" ]]; then
                    s=redux_${SPECPROD}_${d}_$(tr '/' '_' <<<${dd}).sha256sum
                    cd ${dd}
                    if [[ -f ${s} ]]; then
                        if ${test}; then
                            echo "INFO: ${d}/${dd}/${s} already exists."
                        else
                            if validate ${s}; then
                                ${verbose} && echo "INFO: ${d}/${dd}/${s} already exists."
                            else
                                echo "WARNING: ${d}/${dd}/${s} is invalid!"
                            fi
                        fi
                    else
                        # ${verbose} && echo "DEBUG: touch ${SCRATCH}/${s}"
                        # ${test}    || touch ${SCRATCH}/${s}
                        # for f in ${has_files}; do
                        #     ${verbose} && echo "DEBUG: sha256sum ${f} | sed -r 's%^([0-9a-f]+)  (.*)/([^/]+)$%\1  \3%g' >> ${SCRATCH}/${s}"
                        #     ${test}    || sha256sum ${f} | sed -r 's%^([0-9a-f]+)  (.*)/([^/]+)$%\1  \3%g' >> ${SCRATCH}/${s}
                        # done
                        ${verbose} && echo "DEBUG: sha256sum * > ${SCRATCH}/${s}"
                        ${test}    || sha256sum * > ${SCRATCH}/${s}
                        ${verbose} && echo "DEBUG: unlock_and_move ${s}"
                        ${test}    || unlock_and_move ${s}
                    fi
                    cd ${home}/${d}
                fi
            done
        fi
    done
    cd ..
done
