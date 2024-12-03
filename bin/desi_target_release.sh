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
    echo "${execName} [-C] [-h] [-j] [-t] [-v] [-V] RELEASE"
    echo ""
    echo "Prepare targeting data for release."
    echo ""
    echo "Create or verify checksums, prepare tape backups."
    echo ""
    echo "         -C = SKIP checksum file creation."
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
checksum=true
while getopts ChjtvV argname; do
    case ${argname} in
        C) checksum=false ;;
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
public_root=/global/cfs/cdirs/desi/public
export DESI_TARGET=${public_root}/${release}/target
if [[ ! -d ${DESI_TARGET} ]]; then
    echo "ERROR: could not find DESI_TARGET=${DESI_TARGET}! Does the directory exist?"
    exit 1
fi
if ${checksum}; then
    for d in $(find ${DESI_TARGET} -type d); do
        #
        # Does the directory contain files besides a README file?
        #
        d_files=$(find ${d} -maxdepth 1 -type f)
        if [[ -z "${d_files}" ]]; then
            ${verbose} && echo "DEBUG: ${d} does not appear to contain files."
        elif [[ "${d_files}" == "${d}/README" ]]; then
            ${verbose} && echo "DEBUG: ${d} contains only a README file."
        else
            c=$(tr '/' '_' <<<${d#${public_root}/}).sha256sum
            if [[ -f ${d}/${c} ]]; then
                echo "INFO: Existing checksum file found: ${d}/${c}, verifying."
                ${verbose} && echo "DEBUG: (cd ${d} && validate ${c})"
                (cd ${d} && validate ${c})
                if [[ $? == 0 ]]; then
                    ${verbose} && echo "DEBUG: ${d}/${c} is valid."
                else
                    echo "ERROR: Invalid checksum file detected: ${d}/${c}, rebuilding!"
                    ${verbose} && echo "DEBUG: (cd ${d} && unlock_and_resum ${c})"
                    ${test}    || (cd ${d} && unlock_and_resum ${c})
                fi
            else
                echo "INFO: No checksum file found for ${d}, creating."
                ${verbose} && echo "DEBUG: (cd ${d} && unlock_and_resum ${c})"
                ${test}    || (cd ${d} && unlock_and_resum ${c})
            fi
        fi
    done
fi
#
# Create jobs
#
if ${jobs}; then
    job_name=${release}_target_secondary
    cat > ${HOME}/jobs/${job_name}.sh <<EOT
#!/bin/bash
#SBATCH --account=desi
#SBATCH --qos=xfer
#SBATCH --time=12:00:00
#SBATCH --mem=10GB
#SBATCH --job-name=${job_name}
#SBATCH --licenses=cfs,hpss
cd ${DESI_TARGET}
hsi mkdir -p -m 2750 desi/public/${release}/target
htar -cvf desi/public/${release}/target/${job_name}.tar -H crc:verify=all secondary
[[ \$? == 0 ]] && mv -v /global/homes/d/desi/jobs/${job_name}.sh /global/homes/d/desi/jobs/done
EOT

    chmod +x ${HOME}/jobs/${job_name}.sh

    job_name=${release}_target_catalogs_subpriority
    cat > ${HOME}/jobs/${job_name}.sh <<EOT
#!/bin/bash
#SBATCH --account=desi
#SBATCH --qos=xfer
#SBATCH --time=12:00:00
#SBATCH --mem=10GB
#SBATCH --job-name=${job_name}
#SBATCH --licenses=cfs,hpss
cd ${DESI_TARGET}/catalogs
hsi mkdir -p -m 2750 desi/public/${release}/target/catalogs
htar -cvf desi/public/${release}/target/catalogs/${job_name}.tar -H crc:verify=all subpriority
[[ \$? == 0 ]] && mv -v /global/homes/d/desi/jobs/${job_name}.sh /global/homes/d/desi/jobs/done
EOT

    chmod +x ${HOME}/jobs/${job_name}.sh

    for catalog in dr8 dr9 gaiadr2; do
        for version in ${DESI_TARGET}/catalogs/${catalog}/*; do
            v=$(basename ${version})
            job_name=${release}_target_catalogs_${catalog}_${v}
            cat > ${HOME}/jobs/${job_name}.sh <<EOT
#!/bin/bash
#SBATCH --account=desi
#SBATCH --qos=xfer
#SBATCH --time=12:00:00
#SBATCH --mem=10GB
#SBATCH --job-name=${job_name}
#SBATCH --licenses=cfs,hpss
cd ${DESI_TARGET}/catalogs/${catalog}
hsi mkdir -p -m 2750 desi/public/${release}/target/catalogs/${catalog}
htar -cvf desi/public/${release}/target/catalogs/${catalog}/${job_name}.tar -H crc:verify=all ${v}
[[ \$? == 0 ]] && mv -v /global/homes/d/desi/jobs/${job_name}.sh /global/homes/d/desi/jobs/done
EOT

            chmod +x ${HOME}/jobs/${job_name}.sh
        done
    done
fi
