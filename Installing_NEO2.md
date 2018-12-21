
# Installing a NanoPi Neo2 

All based upon the original firmware (FriendlyCore Xenial 4.14 with OLED).
Will I regret that?


- [x] Give it an IP address on the router 

`10.0.0.204`

- [x] Add IP address to hosts/inventory file (`ansible-setup/hosts`)

```
[neo2]
10.0.0.204
```

```shell
$ ansible -i hosts all -u root -k -m ping
SSH password:
10.0.0.204 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

-k to ask for root password (`fa` by default)

- [x] Change root pwd

[The ansible FAQ explains a bit](https://docs.ansible.com/ansible/latest/reference_appendices/faq.html#how-do-i-generate-crypted-passwords-for-the-user-module).

```shell
$ pip install passlib
$ python -c "from passlib.hash import sha512_crypt; import getpass; print(sha512_crypt.using(rounds=5000).hash(getpass.getpass()))"
# use a pwd and save it in a safe place

$ ansible -i hosts all -k -u root -m user -a 'user=root password=Hashed_password_from_prev_cmd'
SSH password:
10.0.0.204 | CHANGED => {
    "append": false,
    "changed": true,
    "comment": "root",
    "group": 0,
    "home": "/root",
    "move_home": false,
    "name": "root",
    "password": "NOT_LOGGING_PASSWORD",
    "shell": "/bin/bash",
    "state": "present",
    "uid": 0
}
✔ ~/Documents/NanoPi/ansible-setup [master|…2]
16:31 $ ansible -i hosts all -k -u root -m ping
SSH password:
10.0.0.204 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

- [x] Set hostname
- [x] Disable the unwanted user names
- [x] Create my user (wheel), test sudo
- [x] Copy ssh keys
- [x] Also make sure the keys are backed up. 

Not really necessary: I am using my own personal keys.

- [x] Disable password login for all
- [x] Update packages
- [ ] Get profile tips from existing templates
- [x] Drop my profiles into place
- [x] Install HomeAssistant
- [ ] Don't put security sensitive stuff into github

After some depreciation warnings, this seems to be the recommended way at present:
```
    - name: Install python 3 and HA requirements
      apt:
        name:
           - python3
        state: present
```

Following [the RPi instructions on the HA site](https://www.home-assistant.io/docs/installation/raspberry-pi/), but with the following changes:

- Not making a separate folder, just using `/home/homeassistant`.
- `RuntimeError: aiohttp 3.x requires Python 3.5.3+`

```shell
$ python3 --version
Python 3.5.2
```

In order to force a newer Python version to be installed, we need to go outside of Ubuntu's defaults. 

Let's add the `deadsnakes` PPA:

```
    - name: Add deadsnakes to get newer Python
      apt_repository:
        repo: ppa:deadsnakes/ppa
```

And install a fixed version of Python. I have not managed to find a way to pin the version other than this one. This does mean, that we will not be automatically upgraded beyond version `3.7`.

```
    - name: Install python 3 and HA requirements
      apt:
        name:
           - python3.7
           - python3.7-venv
           - python3-pip
        state: present
```

TODO:
I manually upgraded PIP:

```shell
python3.7 -m pip install --upgrade pip
```

How to do this using ansible??

- [ ] Configure HA?
- [ ] Backups

```shell

$ rsync -av -e ssh  / pragtich@trapkast:Backup-Neo2

```

Crontab?



- [x] Move this file to Github
- [ ] Investigate using Roles

# Structure

Three playbooks:

1. `setup.yaml` performs setup from initial boot using the root loging.
2. `configure.yaml` continues with configuration using passwordless login.
3. `enable-root.yaml` re-allows root login for when `setup.yaml` needs to be re-run.

Execution:

```shell
$ ansible-playbook -i hosts  -k setup.yaml    # And type in the root password
$ ansible-playbook -i hosts configure.yaml

$ ansible-playbook -i hosts  enable-root.yaml
```

# Notes

## Original `.bashrc`

```shell
# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
```

## Original `.profile`

```shell
# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
	. "$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's private bin directories
PATH="$HOME/bin:$HOME/.local/bin:$PATH"
```

