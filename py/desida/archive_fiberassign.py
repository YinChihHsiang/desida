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
import shutil
from argparse import ArgumentParser
from astropy.io import fits
from desiutil.log import get_logger, DEBUG


log = None


def _options():
    """Parse command-line options.

    Returns
    -------
    :class:`argparse.Namespace`
        The parsed options.
    """
    prsr = ArgumentParser(prog=os.path.basename(sys.argv[0]),
                          description='Create intermediate fiberassign directories.')
    prsr.add_argument('-l', '--limit', type=int, metavar='N',
                      help='Limit moves to N tiles. Default is all tiles.')
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
    tiles_file = os.path.join(os.environ['DESI_ROOT'], 'public', release,
                              'spectro', 'redux',
                              specprod, f'tiles-{specprod}.fits')
    log.debug("tiles_file = '%s'", tiles_file)
    with fits.open(tiles_file, mode='readonly') as hdulist:
        data = hdulist['TILE_COMPLETENESS'].data
    w = data['SURVEY'] == survey
    return data['TILEID'][w].tolist()


def process_tile(tileid, release, survey, test_mode):
    """Process intermediate files associated with `tileid`.

    Parameters
    ----------
    tileid : class`int`
        The unique tile number.
    release : :class:`str`
        Data release, *e.g.* 'dr1'.
    survey : :class:`str`
        Return tiles from this survey.
    test_mode : :class:`bool`
        If ``True``, do not make any changes.

    Returns
    -------
    Something
    """
    tilegroup = tileid//1000
    tilegroup_string = f"{tilegroup:03d}"
    tileid_string = f"{tileid:06d}"
    src = os.path.join(os.environ['DESI_ROOT'], 'survey', 'fiberassign', survey, tilegroup_string)
    dst = os.path.join(os.environ['DESI_ROOT'], 'public', release, 'survey', 'fiberassign', survey, tilegroup_string)
    assert os.path.isdir(src)
    if not os.path.isdir(dst):
        log.debug("os.makedirs('%s')", dst)
        if not test_mode:
            os.makedirs(dst)
    log.debug("glob.glob(os.path.join('%s', '*%s*'))", src, tileid_string)
    tileid_files = glob.glob(os.path.join(src, f"*{tileid_string}*"))
    for tileid_file in tileid_files:
        if os.path.islink(tileid_file):
            log.warning("%s is already a symlink, skipping.", tileid_file)
        else:
            rel_dst = dst.replace(os.environ['DESI_ROOT'], '../../../..')
            tf = os.path.basename(tileid_file)
            log.debug("shutil.move('%s', '%s')", tileid_file, dst)
            log.debug("os.symlink('%s', '%s')", os.path.join(rel_dst, tf), tileid_file)
            if not test_mode:
                shutil.move(tileid_file, dst)
                os.symlink(os.path.join(rel_dst, tf), tileid_file)
    return


def main():
    """Entry-point for command-line scripts.

    Returns
    -------
    :class:`int`
        An integer suitable for passing to :func:`sys.exit`.
    """
    global log
    options = _options()
    if options.verbose:
        log = get_logger()
    else:
        log = get_logger(DEBUG)
    tileids = tiles(options.release, options.specprod, options.survey)
    log.debug("len(tileids) == %d", len(tileids))
    if options.limit is None:
        limit = len(tileids)
    else:
        limit = options.limit
    for tileid in tileids[:limit]:
        process_tile(tileid, options.release, options.survey, options.test)
    return 0


if __name__ == '__main__':
    sys.exit(main())
