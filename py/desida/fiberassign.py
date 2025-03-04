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
from desiutil.log import get_logger, DEBUG


def _options():
    """Parse command-line options.

    Returns
    -------
    :class:`argparse.Namespace`
        The parsed options.
    """
    prsr = ArgumentParser(prog=os.path.basename(sys.argv[0]),
                          description='Create intermediate fiberassign directories.')
    prsr.add_argument('-r', '--release', default='dr1', metavar='RELEASE',
                      help='Data release (default %(default)s).')
    prsr.add_argument('-s', '--specprod', default='iron', metavar='SPECPROD',
                      help='Work with this specprod (default %(default)s).')
    prsr.add_argument('-S', '--survey', default='main', metavar='SURVEY',
                      help='Work with tiles from this survey (default %(default)s).')
    prsr.add_argument('-t', '--test', action='store_true',
                      help="Test mode. Do not make any changes.")
    prsr.add_argument('-v', '--verbose', action='store_true',
                      help="Turn on debug-level logging.")
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
    log = get_logger()
    tiles_file = os.path.join(os.environ['DESI_ROOT'], 'public', release,
                              'spectro', 'redux',
                              specprod, f'tiles-{specprod}.fits')
    log.debug("tiles_file = '%s'", tiles_file)
    with fits.open(tiles_file, mode='readonly') as hdulist:
        data = hdulist['TILE_COMPLETENESS'].data
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
    if options.verbose:
        log = get_logger()
    else:
        log = get_logger(DEBUG)
    tileids = tiles(options.release, options.specprod, options.survey)
    print(tileids)
    log.debug("len(tileids) == %d", len(tileids))
    return 0


if __name__ == '__main__':
    sys.exit(main())
