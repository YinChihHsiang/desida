#!/bin/bash
# Licensed under a 3-clause BSD style license - see LICENSE.rst.
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
    echo "${execName} [-h] [-j JOBS] [-v] [-V] SPECPROD DIRECTORY"
    echo ""
    echo "Create xfer jobs for SPECPROD."
    echo ""
    echo "    -h        = Print this message and exit."
    echo "    -j JOBS   = Use JOBS directory to write batch files (default ${HOME}/jobs)."
    echo "    -v        = Verbose mode. Print extra information."
    echo "    -V        = Version.  Print a version string and exit."
    echo ""
    echo "    SPECPROD  = Spectroscopic Production run name, e.g. 'iron'."
    echo "    DIRECTORY = Create backup jobs for this directory with in SPECPROD."
    ) >&2
}
jobs=${HOME}/jobs
verbose=false
while getopts hj:vV argname; do
    case ${argname} in
        h) usage; exit 0 ;;
        j) jobs=${OPTARG} ;;
        v) verbose=true ;;
        V) version; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done
shift $((OPTIND-1))
if (( $# < 1 )); then
    echo "ERROR: SPECPROD is required!" >&2
    exit 1
fi
if (( $# < 2 )); then
    echo "ERROR: DIRECTORY is required!" >&2
    exit 1
fi
export SPECPROD=$1
directory=$2
[[ -d ${jobs}/done ]] || mkdir -p ${jobs}/done
[[ -z "${DESI_SPECTRO_REDUX}" ]] && export DESI_SPECTRO_REDUX=/global/cfs/cdirs/desi/spectro/redux
if [[ ! -d ${DESI_SPECTRO_REDUX}/${SPECPROD} ]]; then
    echo "ERROR: ${DESI_SPECTRO_REDUX}/${SPECPROD} does not exist!" >&2
    exit 1
fi
for d in ${DESI_SPECTRO_REDUX}/${SPECPROD}/${directory}/*; do
    n=$(basename ${d})
    job_name=redux_${SPECPROD}_$(tr '/' '_' <<<${directory})_${n}
    ${verbose} && echo "DEBUG: job_name=${job_name}" >&2
    cat > ${jobs}/${job_name}.sh <<EOT
#!/bin/bash
#SBATCH --account=desi
#SBATCH --qos=xfer
#SBATCH --time=12:00:00
#SBATCH --mem=10GB
#SBATCH --job-name=${job_name}
#SBATCH --output=${jobs}/${job_name}-%j.log
#SBATCH --licenses=cfs
cd ${DESI_SPECTRO_REDUX}/${SPECPROD}/${directory}
hsi mkdir -p desi/spectro/redux/${SPECPROD}/${directory}
htar -cvf desi/spectro/redux/${SPECPROD}/${directory}/${job_name}.tar -H crc:verify=all ${n}
[[ \$? == 0 ]] && mv -v ${jobs}/${job_name}.sh ${jobs}/done
EOT
    ${verbose} && echo "DEBUG: chmod +x ${jobs}/${job_name}.sh" >&2
    chmod +x ${jobs}/${job_name}.sh
done
