"""run built exes

run [target]
run [target] [config]
"""

from mod import log, util, config, project, settings

#-------------------------------------------------------------------------------
def run(fips_dir, proj_dir, args) :
    """run fips project build targets"""
    if not util.is_valid_project_dir(proj_dir) :
        log.error('must be run in a project directory')
    cfg_name = settings.get(proj_dir, 'config')
    target_name = settings.get(proj_dir, 'target')
    target_args = []
    if '--' in args :
        idx = args.index('--')
        target_args = args[(idx + 1):]
        args = args[:idx]
    if len(args) > 0 :
        target_name = args[0]
    if len(args) > 1 :
        cfg_name = args[1]
    if target_name :
        project.run(fips_dir, proj_dir, cfg_name, target_name, target_args)
    else :
        log.error('no target provided')


#-------------------------------------------------------------------------------
def help() :
    """print run help"""
    log.info(log.YELLOW + 
            "fips run\n"
            "fips run [target]\n" 
            "fips run [target] [config]\n" + log.DEF +
            "   run a build target for current or named config")

