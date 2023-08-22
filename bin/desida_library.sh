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
    mv ${filename} . || return $?
    chmod u-w $(basename ${filename})
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
    mv ${SCRATCH}/${filename} . || return $?
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
#
# Raw data nights in each release.
#
function is_night_in_release() {
    local release=$1
    local night=$2
    if [[ "${release}" == "edr" ]]; then
        (( ${night} >= 20200201 && ${night} < 20210514 )) && return 0
        (( ${night} == 20210517 || ${night} == 20210518 || ${night} == 20210521 || ${night} == 20210529 || ${night} == 20210610 )) && return 0
    fi
    if [[ "${release}" == "dr1" ]]; then
        (( ${night} == 20210517 || ${night} == 20210518 || ${night} == 20210521 || ${night} == 20210529 || ${night} == 20210610 )) && return 1
        (( ${night} >= 20210514 && ${night} < 20220614 )) && return 0
    fi
    return 1
}
