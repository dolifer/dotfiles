ZDOTDIR=~/.zsh

# Load configurations
for rc in $ZDOTDIR/*.sh
do
    source $rc
done
unset rc