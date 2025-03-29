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
if [[ "${release}" != "edr" && "${release}" != "dr1" && "${release}" != "dr2" ]]; then
    echo "ERROR: Undefined release=${release}!"
    exit 1
fi
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
for n in ${DESI_SPECTRO_DATA}/20*; do
    night=$(basename ${n})
    if is_night_in_release ${release} ${night}; then
        echo "INFO: Processing night=${night}."
        for e in ${DESI_SPECTRO_DATA}/${night}/*; do
            expid=$(basename ${e})
            ${verbose} && echo "DEBUG: Processing expid=${expid}."
            c=checksum-${expid}.sha256sum
            if [[ -f ${e}/${c} ]]; then
                ${verbose} && echo "DEBUG: ${e}/${c} exists."
            elif [[ -f ${e}/checksum-${night}-${expid}.sha256sum ]]; then
                c=checksum-${night}-${expid}.sha256sum
                ${verbose} && echo "DEBUG: ${e}/${c} exists."
            else
                echo "WARNING: ${e} has no checksum file!"
                ${verbose} && echo "DEBUG: echo ${night} >> ${redo}"
                ${test}    || echo ${night} >> ${redo}
                ${verbose} && echo "DEBUG: (cd ${e} && sha256sum * > ${SCRATCH}/${c} && unlock_and_move ${c})"
                ${test}    || (cd ${e} && sha256sum * > ${SCRATCH}/${c} && unlock_and_move ${c})
            fi
            ${verbose} && echo "DEBUG: (cd ${e} && validate ${c})"
            ${test}    || (cd ${e} && validate ${c})
            if [[ $? == 0 ]]; then
                ${verbose} && echo "DEBUG: ${e}/${c} is valid."
            elif [[ $? == 17 ]]; then
                echo "WARNING: File number mismatch in ${e}/${c}!"
                ${verbose} && echo "DEBUG: echo ${night} >> ${redo}"
                ${test}    || echo ${night} >> ${redo}
                ${verbose} && echo "DEBUG: (cd ${e} && unlock_and_resum ${c})"
                ${test}    || (cd ${e} && unlock_and_resum ${c})
            else
                echo "WARNING: Checksum error detected for ${e}/${c}!"
                ${verbose} && echo "DEBUG: echo ${night} >> ${redo}"
                ${test}    || echo ${night} >> ${redo}
                ${verbose} && echo "DEBUG: (cd ${e} && unlock_and_resum ${c})"
                ${test}    || (cd ${e} && unlock_and_resum ${c})
            fi
        done
    fi
done
#
# Redo backups of changed nights
#
for night in $(cat ${redo} | sort -n | uniq); do
    job_name=desi_spectro_data_${night}
    cat > ${HOME}/jobs/${job_name}.sh <<EOT
#!/bin/bash
#SBATCH --account=desi
#SBATCH --qos=xfer
#SBATCH --time=12:00:00
#SBATCH --mem=10GB
#SBATCH --job-name=${job_name}
#SBATCH --licenses=cfs,hpss
cd ${DESI_SPECTRO_DATA}
htar -cvf desi/spectro/data/${job_name}.tar -H crc:verify=all ${night}
[[ \$? == 0 ]] && mv -v /global/homes/d/desi/jobs/${job_name}.sh /global/homes/d/desi/jobs/done
EOT

    chmod +x ${HOME}/jobs/${job_name}.sh
done
