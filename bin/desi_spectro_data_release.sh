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
    echo "${execName} [-h] [-j] [-t] [-v] [-V] RELEASE"
    echo ""
    echo "Prepare raw data (DESI_SPECTRO_DATA) for release."
    echo ""
    echo "Verify checksums, redo tape backups if necessary."
    echo ""
    echo "         -h = Print this message and exit."
    echo "         -j = Generate tape backup jobs."
    echo "         -t = Test mode.  Do not actually make any changes. Implies -v."
    echo "         -v = Verbose mode. Print extra information."
    echo "         -V = Version.  Print a version string and exit."
    echo "    RELEASE = Name of release, e.g. 'edr'."
    ) >&2
}
#
# Get options.
#
jobs=false
test=false
verbose=false
while getopts hjtvV argname; do
    case ${argname} in
        h) usage; exit 0 ;;
        j) jobs=true ;;
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
                ${verbose} && echo "DEBUG: ${expid}/${c} exists."
            else
                echo "WARNING: ${expid} has no checksum file!"
                ${verbose} && echo "DEBUG: echo ${n} >> ${redo}"
                ${test}    || echo ${n} >> ${redo}
                ${verbose} && echo "DEBUG: (cd ${expid} && sha256sum * > ${SCRATCH}/${c} && unlock_and_move ${c})"
                ${test}    || (cd ${expid} && sha256sum * > ${SCRATCH}/${c} && unlock_and_move ${c})
            fi
            ${verbose} && echo "DEBUG: (cd ${expid} && validate ${c})"
            ${test}    || (cd ${expid} && validate ${c})
            if [[ $? == 0 ]]; then
                ${verbose} && echo "DEBUG: ${expid}/${c} is valid."
            elif [[ $? == 17 ]]; then
                echo "WARNING: File number mismatch in ${expid}/${c}!"
                ${verbose} && echo "DEBUG: echo ${n} >> ${redo}"
                ${test}    || echo ${n} >> ${redo}
                ${verbose} && echo "DEBUG: (cd ${expid} && unlock_and_resum ${c})"
                ${test}    || (cd ${expid} && unlock_and_resum ${c})
            else
                echo "WARNING: Checksum error detected for ${expid}/${c}!"
                ${verbose} && echo "DEBUG: echo ${n} >> ${redo}"
                ${test}    || echo ${n} >> ${redo}
                ${verbose} && echo "DEBUG: (cd ${expid} && unlock_and_resum ${c})"
                ${test}    || (cd ${expid} && unlock_and_resum ${c})
            fi
        done
    fi
done
#
# Redo backups of changed nights
#
redo_unique=${DESIDA}/redo_nights_unique.txt
for n in $(cat ${redo} | sort -n | uniq); do
    grep -q ${n} ${redo_unique}
    if [[ $? != 0 ]]; then
        echo "WARNING: New unique redo night = ${n}!"
    fi
done
if jobs; then
    for n in $(<${redo_unique}); do
        job_name=desi_spectro_data_${n}
        cat > ${HOME}/jobs/${job_name}.sh <<EOT
#!/bin/bash
#SBATCH --account=desi
#SBATCH --qos=xfer
#SBATCH --time=12:00:00
#SBATCH --mem=10GB
#SBATCH --job-name=${job_name}
#SBATCH --licenses=cfs
cd ${DESI_SPECTRO_DATA}
htar -cvf desi/spectro/data/${job_name}.tar -H crc:verify=all ${n}
[[ \$? == 0 ]] && mv -v /global/homes/d/desi/jobs/${job_name}.sh /global/homes/d/desi/jobs/done
EOT

    done
fi
