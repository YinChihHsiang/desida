# Licensed under a 3-clause BSD style license - see LICENSE.rst.
"""
==================
desida.fiberassign
==================

Tools for working with *intermediate* fiberassign files, *i.e.* ``${DESI_ROOT}/survey/fiberassign``.
"""
import os
import sys
import glob
from argparse import ArgumentParser
from astropy.io import fits


def _options():
    """Parse command-line options.

    Returns
    -------
    """
    prsr = ArgumentParser(prog=os.path.basename(sys.argv[0]),
                          description='Create intermediate fiberassign directories.')
    prsr.add_argument('-r', '--release', default='dr1', metavar='RELEASE',
                      help='Data release (default %(default)s).')
    prsr.add_argument('-s', '--specprod', default='iron', metavar='SPECPROD',
                      help='Work with this specprod (default %(default)s).')
    prsr.add_argument('-S', '--survey', default='main', metavar='SURVEY',
                      help='Work with tiles from this survey (default %(default)s).')
    return prsr.parse_args()


def tiles(release, specprod, survey):
    """Obtain the list of tiles from `survey` to be processed.

    Parameters
    ----------
    release : :class:`str`
        Data release, *e.g.* 'dr1'.
    specprod : :class:`str`
        Specprod name, *e.g.* 'iron'.
    survey : :class:`str`
        Return tiles from this survey.

    Returns
    -------
    :class:`list`
        The list of tiles from `survey`.
    """
    tiles_file = os.path.join(os.environ['DESI_ROOT'], 'public', release,
                              'spectro', 'redux',
                              specprod, f'tiles-{specprod}.fits')
    with fits.open(tiles_file, mode='readonly') as hdulist:
        data = hdulist['TILES'].data
    w = data['SURVEY'] == survey
    return data['TILEID'][w].tolist()


def main():
    """Entry-point for command-line scripts.

    Returns
    -------
    :class:`int`
        An integer suitable for passing to :func:`sys.exit`.
    """
    options = _options()
    tileids = tiles(options.release, options.specprod, options.survey)
    print(tileids)
    return 0


if __name__ == '__main__':
    sys.exit(main())
