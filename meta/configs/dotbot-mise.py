import os
import subprocess
import dotbot

class Mise(dotbot.Plugin):
    _directive = 'mise'

    def can_handle(self, directive):
        return directive == self._directive

    def handle(self, directive, data):
        if directive != self._directive:
            raise ValueError('Mise cannot handle directive %s' % directive)
        
        success = True
        
        # Check if mise is installed
        if subprocess.call('command -v mise >/dev/null 2>&1', shell=True) != 0:
            self._log.error('mise is not installed or not in PATH')
            return False

        self._log.info('Running mise install...')
        
        try:
            # Run mise install in the home directory so it picks up global/local configs correctly
            subprocess.check_call(['mise', 'install'], cwd=os.path.expanduser('~'))
            self._log.info('Successfully ran mise install')
        except subprocess.CalledProcessError as e:
            self._log.error('Failed to run mise install: %s' % e)
            success = False
            
        return success
