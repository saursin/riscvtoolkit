# Sets up the toolkit in the current shell (bash, zsh):  source <toolkit>/env.sh
if [ -n "${BASH_SOURCE:-}" ]; then
    _tk_env=${BASH_SOURCE[0]}
elif [ -n "${ZSH_VERSION:-}" ]; then
    eval '_tk_env=${(%):-%x}'
else
    echo "env.sh: source it from bash or zsh" >&2
    return 1
fi
RISCVTOOLKIT=$(cd "$(dirname "$_tk_env")" && pwd)
export RISCVTOOLKIT
case ":$PATH:" in
    *":$RISCVTOOLKIT/bin:"*) ;;
    *) export PATH="$RISCVTOOLKIT/bin:$PATH" ;;
esac
unset _tk_env
