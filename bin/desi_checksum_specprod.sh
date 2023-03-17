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
    echo "${execName} [-h] [-j JOBS] [-s DIR] [-V] SPECPROD"
    echo ""
    echo "Checksum an entire spectroscopic reduction (SPECPROD) in preparation"
    echo "for tape backup."
    echo ""
    echo "Assuming files are on disk are in a clean, archival state, this script"
    echo "will create checksum files for the entire data set."
    echo ""
    echo "    -h      = Print this message and exit."
    echo "    -j JOBS = Use JOBS directory to write batch files (default ${HOME}/jobs)."
    echo "    -s DIR  = Use DIR for temporary files (default ${SCRATCH})."
    echo "    -V      = Version.  Print a version string and exit."
    ) >&2
}
#
# Create jobs.
#
function create_checksum_job() {
    local checksum_name=$1
    shift
    local checksum_dir=$(dirname ${checksum_name})
    local checksum_file=$(basename ${checksum_name})
    local job_name=${checksum_file%.sha256sum}
    if [[ "$@" == "." ]]; then
        local command="find . -type f -exec sha256sum \{\} \;"
    else
        local command="sha256sum $@"
    fi
    cat > ${jobs}/${job_name}.sh <<EOT
#!/bin/bash
#SBATCH --account=desi
#SBATCH --qos=xfer
#SBATCH --time=12:00:00
#SBATCH --mem=10GB
#SBATCH --job-name=${job_name}
#SBATCH --output=${jobs}/${job_name}-%j.log
#SBATCH --licenses=cfs
source /global/common/software/desi/desi_environment.sh main
module load desida desiBackup
source ${DESIDA}/bin/desida_library.sh
set -o xtrace
cd ${checksum_dir}
if [[ -f ${checksum_file} ]]; then
    validate ${checksum_file} && mv ${jobs}/${job_name}.sh ${jobs}/done
else
    ${command} > ${scratch}/${checksum_file}
    [[ \$? == 0 ]] && unlock_and_move ${scratch}/${checksum_file} && mv ${jobs}/${job_name}.sh ${jobs}/done
fi
EOT
    chmod +x ${jobs}/${job_name}.sh
}
#
# Get options.
#
jobs=${HOME}/jobs
scratch=${SCRATCH}
while getopts hj:s:V argname; do
    case ${argname} in
        h) usage; exit 0 ;;
        j) jobs=${OPTARG} ;;
        s) scratch=${OPTARG} ;;
        V) version; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done
shift $((OPTIND-1))
if [[ $# < 1 ]]; then
    echo "ERROR: SPECPROD must be defined on the command-line!" >&2
    exit 1
fi
export SPECPROD=$1
if [[ ! -d ${DESI_SPECTRO_REDUX}/${SPECPROD} ]]; then
    echo "ERROR: ${DESI_SPECTRO_REDUX}/${SPECPROD} does not exist!" >&2
    exit 1
fi
#
# Top-level files
#
home=${DESI_SPECTRO_REDUX}/${SPECPROD}
cd ${home}
create_checksum_job ${DESI_SPECTRO_REDUX}/${SPECPROD}/redux_${SPECPROD}.sha256sum exposures-${SPECPROD}.\* tiles-${SPECPROD}.\*
#
# tilepix.* files in healpix directory
#
create_checksum_job ${DESI_SPECTRO_REDUX}/${SPECPROD}/healpix/redux_${SPECPROD}_healpix.sha256sum tilepix.\*
#
# calibnight, exposure_tables
#
for d in calibnight exposure_tables; do
    cd ${d}
    for night in *; do
        create_checksum_job ${DESI_SPECTRO_REDUX}/${SPECPROD}/${d}/${night}/redux_${SPECPROD}_${d}_${night}.sha256sum \*
    done
    cd ..
done
#
# processing_tables, run, zcatalog
#
create_checksum_job ${DESI_SPECTRO_REDUX}/${SPECPROD}/processing_tables/redux_${SPECPROD}_processing_tables.sha256sum \*
create_checksum_job ${DESI_SPECTRO_REDUX}/${SPECPROD}/run/redux_${SPECPROD}_run.sha256sum .
create_checksum_job ${DESI_SPECTRO_REDUX}/${SPECPROD}/zcatalog/redux_${SPECPROD}_zcatalog.sha256sum \*
create_checksum_job ${DESI_SPECTRO_REDUX}/${SPECPROD}/zcatalog/logs/redux_${SPECPROD}_zcatalog_logs.sha256sum \*
#
# exposures, preproc
#
for d in exposures preproc; do
    cd ${d}
    for night in *; do
        cd ${night}
        for expid in *; do
            if is_empty ${expid}; then
                echo "WARNING: ${d}/${night}/${expid} is empty." >&2
            else
                create_checksum_job ${DESI_SPECTRO_REDUX}/${SPECPROD}/${d}/${night}/${expid}/redux_${SPECPROD}_${d}_${night}_${expid}.sha256sum \*
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
                    create_checksum_job ${DESI_SPECTRO_REDUX}/${SPECPROD}/${d}/${dd}/${s} \*
                fi
            done
        fi
    done
    cd ..
done
