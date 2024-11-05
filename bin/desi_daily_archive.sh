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
    echo "${execName} [-B] [-h] [-j JOBS] [-s DIR] [-V] [-v]"
    echo ""
    echo "Generate checksum and backup jobs for spectro/redux/daily/tiles/archive."
    echo ""
    echo "Assuming files are on disk are in a clean, archival state, this script"
    echo "will create checksum files for the entire data set."
    echo ""
    echo "    -B         = If set, do NOT submit batch jobs."
    echo "    -h         = Print this message and exit."
    echo "    -j JOBS    = Use JOBS directory to write batch files (default ${DESI_ROOT}/users/${USER}/jobs)."
    echo "    -s DIR     = Use DIR for temporary files (default ${SCRATCH})."
    echo "    -V         = Version. Print a version string and exit."
    echo "    -v         = Verbose mode. Print extra information."
    echo ""
    ) >&2
}
#
# Create jobs.
#
function create_archivedate_job() {
    local tileid=$1
    local archivedate=$2
    local logs=$3
    local job_name="redux_daily_tiles_archive_${tileid}_${archivedate}"
    # local checksum_dir=$(dirname ${checksum_name})
    # local checksum_file=$(basename ${checksum_name})
    cat > ${jobs}/${job_name}.sh <<EOT
#!/bin/bash
#SBATCH --account=desi
#SBATCH --qos=xfer
#SBATCH --constraint=cron
#SBATCH --time=4:00:00
#SBATCH --job-name=${job_name}
#SBATCH --output=${jobs}/%x-%j.log
#SBATCH --licenses=cfs,scratch
source /global/common/software/desi/desi_environment.sh main
module load desida desiBackup
source \${DESIDA}/bin/desida_library.sh
set -o xtrace
shopt -s extglob
if [[ "${logs}" == "True" ]]; then
    cd \${DESI_SPECTRO_REDUX}/daily/tiles/archive/${tileid}/${archivedate}/logs
    sha256sum * > ${scratch}/${job_name}_logs.sha256sum
    unlock_and_move ${scratch}/${job_name}_logs.sha256sum
fi
cd \${DESI_SPECTRO_REDUX}/daily/tiles/archive/${tileid}/${archivedate}
sha256sum !(logs) > ${scratch}/${job_name}.sha256sum
unlock_and_move ${scratch}/${job_name}.sha256sum
cd \${DESI_SPECTRO_REDUX}/daily/tiles/archive
htar -cvf desi/spectro/redux/daily/tiles/archive/${job_name}.tar -H crc:verify=all ${tileid}/${archivedate}
[[ \$? == 0 ]] && mv -v ${jobs}/${job_name}.sh ${jobs}/done
EOT
    chmod +x ${jobs}/${job_name}.sh
}
#
# Get options.
#
batch=true
jobs=${DESI_ROOT}/users/${USER}/jobs
scratch=${SCRATCH}
verbose=false
while getopts hj:s:Vv argname; do
    case ${argname} in
        B) batch=false ;;
        h) usage; exit 0 ;;
        j) jobs=${OPTARG} ;;
        s) scratch=${OPTARG} ;;
        V) version; exit 0 ;;
        v) verbose=true ;;
        *) usage; exit 1 ;;
    esac
done
#
# Create job directories.
#
[[ -d ${jobs}/done ]] || mkdir -p ${jobs}/done
#
# Find TILEID/ARCHIVEDATE directories.
#
archive_dir=${DESI_SPECTRO_REDUX}/daily/tiles/archive
for tile_dir in ${archive_dir}/*; do
    tileid=$(basename ${tile_dir})
    for archivedate_dir in ${tile_dir}/*; do
        archivedate=$(basename ${archivedate_dir})
        checksum_file=redux_daily_tiles_archive_${tileid}_${archivedate}.sha256sum
        if [[ -f ${archivedate_dir}/${checksum_file} ]]; then
            ${verbose} && echo "DEBUG: ${archivedate_dir}/${checksum_file} detected, skipping ${tileid}/${archivedate}."
        else
            echo "INFO: ${tileid}/${archivedate} will be backed up."
            logs='False'
            if [[ -d ${archivedate_dir}/logs ]]; then
                ${verbose} && echo "DEBUG: ${tileid}/${archivedate}/logs will be checksummed."
                logs='True'
            fi
            create_archivedate_job ${tileid} ${archivedate} ${logs}
        fi
    done
done
#
# Submit a workflow job that will submit the batch jobs
#
${batch} && sbatch ${jobs}/submit_daily_tiles_archive.sh
