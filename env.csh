# Sets up the toolkit in the current shell (tcsh):  source <toolkit>/env.csh
# csh cannot name the file it sources; tcsh keeps it open, so its path is under /proc/$$/fd.
set _tk_env = `ls -l /proc/$$/fd | sed -n 's|.* -> \(/.*/env\.csh\)$|\1|p' | tail -1`
if ("$_tk_env" == "") then
    echo "env.csh: cannot find the toolkit folder"
    exit 1
endif
setenv RISCVTOOLKIT "$_tk_env:h"
unset _tk_env
if (":${PATH}:" !~ *":${RISCVTOOLKIT}/bin:"*) setenv PATH "${RISCVTOOLKIT}/bin:${PATH}"
