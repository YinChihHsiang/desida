# Licensed under a 3-clause BSD style license - see LICENSE.rst.
"""
================
desida.inventory
================

Tools for complete listings of data assembly files.
"""
import os
import sys
from desiutil.log import log


def checksum_contents(checksum_file):
    """Parse the contents of `checksum_file`.

    Parameters
    ----------
    checksum_file : :class:`str`
        The checksum file to parse.

    Returns
    -------
    :class:`dict`
        A dictionary mapping filename to checksum value.
    """
    d = os.path.dirname(checksum_file)
    r = dict()
    with open(checksum_file) as c:
        lines = c.readlines()
    for l in lines:
        foo = l.strip().split()
        r[os.path.normpath(os.path.join(d, foo[1]))] = foo[0]
    return r


def find_all_files(root, cext='.sha256sum'):
    """Build up a catalog of all files in a directory tree.

    Parameters
    ----------
    root : :class:`str`
        The root of the directory tree to explore.
    cext : :class:`str`, optional
        Use this filename extension to identify checksum files.

    Returns
    -------
    :class:`tuple`
        A tuple of two dictionaries: the first is a mapping of
        directory to files in that directory.  The second is a mapping of
        checksum files to the contents of those checksum files.
    """
    directories = dict()
    checksums = dict()
    for dirpath, dirnames, filenames in os.walk(root, followlinks=True):
        directories[dirpath] = filenames.copy()
        for d in dirnames:
            dd = os.path.join(dirpath, d)
            if d.startswith('.'):
                log.warning('Hidden directory detected: %s!', dd)
        for f in filenames:
            ff = os.path.join(dirpath, f)
            if f.startswith('.'):
                log.warning('Hidden file detected: %s!', ff)
            if os.path.splitext(f)[1] == cext:
                log.info("Checksum file detected: %s.", ff)
                log.debug("checksums['%s'] = checksum_contents('%s')", ff, ff)
                checksums[ff] = checksum_contents(ff)

def main():
    """Entry-point for command-line scripts.

    Returns
    -------
    :class:`int`
        An integer suitable for passing to :func:`sys.exit`.
    """
    directories, checksums = find_all_files(sys.argv[1])
    print(directories)
    print(checksums)
    return 0
