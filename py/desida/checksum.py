# Licensed under a 3-clause BSD style license - see LICENSE.rst.
"""
===============
desida.checksum
===============

Tools for working with checksum files.
"""
import os
from desiutil.log import log


def missing_specprod_checksums(specprod):
    """Find missing checksum files in `specprod`.

    Parameters
    ----------
    specprod : :class:`str`
        The spectroscopic production run, *e.g.* ``iron``.

    Returns
    -------
    :class:`int`
        The number of missing files.
    """
    n_missing = 0
    spectro = os.path.join(os.environ['DESI_ROOT'], 'spectro')
    top = os.path.join(os.environ['DESI_SPECTRO_REDUX'], specprod)
    for dirpath, dirnames, filenames in os.walk(top):
        c = dirpath.replace(spectro + '/', '').replace('/', '_') + '.sha256sum'
        if os.path.basename(dirpath) == 'run':
            if os.path.exists(os.path.join(dirpath, c)):
                log.debug("%s exists.", c)
                dirnames.clear()
            else:
                log.error("%s not found!", c)
                n_missing += 1
        else:
            if filenames:
                if not os.path.exists(os.path.join(dirpath, c)):
                    log.error("%s not found!", c)
                    n_missing += 1
    return n_missing


def main():
    """Entry-point for command-line scripts.

    Returns
    -------
    :class:`int`
        An integer suitable for passing to :func:`sys.exit`.
    """
    specprod = 'iron'
    n = missing_specprod_checksums(specprod)
    return n
