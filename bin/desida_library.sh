#
# Licensed under a 3-clause BSD style license - see LICENSE.rst.
#
# Common code for use with desida:
#
# source ${DESIDA}/bin/desida_library.sh
#
#
# Version string.
#
function version() {
    local execName=$(basename $0)
    (
    cd ${DESIDA}
    local tags=$(git describe --tags --dirty --always | cut -d- -f1)
    local revs=$(git rev-list --count HEAD)
    echo "${execName} version: ${tags}.dev${revs}"
    ) >&2
}
#
# Move an existing file.
#
function unlock_and_move() {
    local filename=$1
    chmod u+w .
    mv ${SCRATCH}/${filename} .
    chmod u-w ${filename}
    chmod u-w .
}
#
# Remove and create a new file.
#
function unlock_and_resum() {
    local filename=$1
    chmod u+w .
    /bin/rm -f ${filename}
    sha256sum * > ${SCRATCH}/${filename}
    mv ${SCRATCH}/${filename} .
    chmod u-w ${filename}
    chmod u-w .
}
#
# Empty directories.
#
function is_empty() {
    local directory=$1
    [[ -z "$(/bin/ls -A ${directory})" ]]
}
#
# Validate checksums.
#
function validate() {
    local checksum=$1
    local depth='-maxdepth 1'
    [[ -n "$2" ]] && depth=''
    local n_files=$(find . ${depth} -not -type d | wc -l)
    local n_lines=$(cat ${checksum} | wc -l)
    (( n_files == n_lines + 1 )) || return 17
    sha256sum --status --check ${checksum}
}
