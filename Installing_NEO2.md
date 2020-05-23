
# Installing a NanoPi Neo2 

I chose to try and use Ansible in order to create a reproducible setup for my cute & low powered [NanoPi NEO2](https://www.friendlyarm.com/index.php?route=product/product&product_id=180). It's a great little board, really not very expensive and incredibly small. The aluminium housing especially took my fancy, giving a nice OLED display and a few buttons. That's why I got the [NEO2 Metal Complete Kit](https://www.friendlyarm.com/index.php?route=product/product&product_id=189).

I chose to make the system based on Armbian Bionic, since my previous experience of manufacturer's own distributions has been, that they find it difficult to stay up to date for any period of time. Better to use a well-known and stable Linux such as Armbian or DietPi. I chose Armbian because of its advertised support for the NEO2, and was not disappointed. Perhaps some specific hardware support might be easier when working with the manufacturer's own distributions, but for now I am very happy.


# Task list #


- [x] Give it an IP address on the router 
- [x] Add IP address to hosts/inventory file (`ansible-setup/hosts`)
- [x] Set hostname
- [x] Disable the unwanted user names
- [x] Create my user (wheel), test sudo
- [x] Copy ssh keys
- [x] Also make sure the keys are backed up. 
- [x] Disable password login for all
- [x] Update packages
- [x] Get profile tips from existing templates
- [x] Drop my profiles into place
- [x] Install HomeAssistant
- [x] Don't put security sensitive stuff into github
- [x] Move homeassistant `configuration.yaml` into ansible
- [ ] Backups
- [x] Move this file to Github
- [ ] Investigate using Roles to modularize stuff (eg config transfer)
- [x] Investigate how the removal/dissuation of YAML impacts this project.
Answer: not much, but I need to copy the entire `.homeassistant` folder and subfolders, not just the `*.yaml` files.
- [ ] Transfer an entire skeleton folder, not just the config files
- [ ] Configure zones
- [ ] Check weither I need to document more of the steps
- [ ] Move Homeassistant config to Git repository
- [ ] Move to [more up to date config methods](https://www.home-assistant.io/blog/2020/04/14/the-future-of-yaml/)
- [ ] Configure interesting add-ins



# IP Address and initial configuration #

When the computer first boots up from a freshly flashed Armbian SD card, it will take a while to setup the system, but will finally try to come online on the Ethernet port by means of DHCP. It can also be reached via a serial device which is offered through the USB power connection. This does not seem to be a console connection (this is available elsewhere on the board), but rather a 'traditional' serial terminal connection. It runs at 9600 baud.

Upon first login, (`root` with password `1234`), the user is asked to enter a new `root` password, and to create a proper user account. This is essential for the following to work, since we use this account for logging in with Ansible.

The IP address can be found by a port scan, by checking the router's DHCP client list, or by logging in through the USB serial port. This address and a hostname need to be added to a catalog file:

```
[neo2]
10.0.0.3
```

Then, Ansible can be tested.

```shell
$ ansible -i hosts all -u root -k -m ping
SSH password:
10.0.0.204 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

Update May 2020: ping now fails on the first try:

```shell
10.0.0.3 | FAILED! => {
    "msg": "to use the 'ssh' connection type with passwords, you must install the sshpass program"
}
```

So let's install `sshpass` and test again:

```shell
$ brew install sshpass
Error: No available formula with the name "sshpass"
We won't add sshpass because it makes it too easy for novice SSH users to
ruin SSH's security.
```
That seems to be not the way to go.

```shell
curl -O -L https://fossies.org/linux/privat/sshpass-1.06.tar.gz && tar xvzf sshpass-1.06.tar.gz
cd sshpass-1.06
./configure
sudo make install
```

That runs without problems, and then:

```shell
10:44 $ ansible -i hosts  neo2 -m ping --ask-pass
SSH password:
10.0.0.3 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

Hello world!

# Setup the system with the basics #

Some of the first things that need to be done after the first login, prepare the sytem. For example, I enable passwordless login for the user account and disable passworded root login. These preparations need only be done once, and require a root password, so I split them out into a separate playbook: `setup.yaml`. [Here on Github](https://github.com/pragtich/ansible-setup/blob/master/setup.yaml).




## Change root pwd ##

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

## Add a user ##

Just in case I forgot to login for the first time, or I do not want to, create a user for general use, and allow key login.

```
  - name: Add a user for myself
    user:
      name:        "{{ PR8_USER }}"
      password:    "{{ PR8_USER_PWD }}"
      shell:       "{{ PR8_SHELL }}"
      generate_ssh_key: yes
      groups:
        - sudo
        - dialout
      append:      yes
  - name: Make a local copy of the private key
    become_user: "{{ PR8_USER }}"
    become: yes
    fetch:
      src: ~/.ssh/id_rsa.pub
      dest: "{{ ansible_hostname }}_key.pub"
  - name: Allow key login for my user
    authorized_key:
      user: "{{ PR8_USER }}"
      key: "{{ lookup('file', item) }}"
    with_items: "{{ PR8_KEYS }}"
```



# Installing Python #

We need a new-ish version of Python in order to support Homeassistant.


Following [the RPi instructions on the HA site](https://www.home-assistant.io/docs/installation/raspberry-pi/), but with the following changes:

- Not making a separate folder, just using `/home/homeassistant`.

In order to force a newer Python version to be installed, we need to go outside of Debian's defaults. In general it is a good thing that Debian is quite conservative with its packages. One of the most annoying things in Linux in general, in my opinion, is stuff breaking all the time. But in this case, we do need a somewhat less conservative version. Anyway, Python is so heavily used, that any problem shoud be fixed very quickly.

Let's add the `deadsnakes` PPA, that's where a lot of more recent Pythons are distributed:

```
    - name: Add deadsnakes to get newer Python
      apt_repository:
        repo: ppa:deadsnakes/ppa
    - name: apt upgrade
      become: yes
      apt:
        update_cache:     yes
        cache_valid_time: 3600
        upgrade:          safe
```

And install a fixed version of Python. I have not managed to find a way to pin the version other than this one. This does mean, that we will not be automatically upgraded beyond version `3.7`.

We are installing some requirements right away, since we are going to need them for installing Homeassistant:

```
    - name: Install python 3 and HA requirements
      apt:
        name:
           - python3.7
           - python3.7-venv
		   - python3.7-dev
           - python3-pip
           - python3-setuptools
		   - libffi-dev
		   - libssl-dev
        state: present
```

# Install Homeassistant in a virtualenv #

```
    - name: Create systemd service for homeassistant
      #TODO: cant I make user modules?
	  become: yes
      copy:
        src:   home-assistant@homeassistant.service
        dest:  /lib/systemd/system/
```


I would like to install the Homeassistant service as a user service. According to [a remark on the great ArchWiki](https://wiki.archlinux.org/index.php/Systemd/User#Automatic_start-up_of_systemd_user_instances), it is possible to get a user service to run upon boot. Let's try to get this installed by Ansible. For now, I am using a system service with `systemd`'s `User=` feature. 


# Start Homeassistant automatically #

The easiest way is to copy the systemd service file that's supplied by Homeassistant using the `copy` module. This does require `root` access. Some day I might figure out how to install a user service, but for now this works fine.

# Transfer the Homeassistant configuration #

I find it convenient to also use the `copy` module to transfer all the YAML configuration files. We'll have to see how the Homeassistant development changes in the future ([it seems that YAML is getting less popular](https://www.home-assistant.io/blog/2020/04/14/the-future-of-yaml/)), but for now this will work.

The most important gotcha that I found is, that we need to be sure that the files are transferred with the correct `owner` and `group`, otherwise we'll have issues writing to the files in the future. 

My idea is to make sure that all permanent changes to the configuration are created from Ansible. That should help to reinstall everything easily in case that something were to fail. Another way would be to make sure that the configuration lives in a Git repository somewhere, that might be a nice project for the future.

# Backups #

```shell

$ rsync -av -e ssh  /home pragtich@trapkast:Backup-Neo2

```

Crontab?




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

# Move passwords to a vault

```shell
ansible-vault create pr8-vault.yaml
```

Come up with a decent password and when the `EDITOR` is opened, put in the first variables:

```yaml
    PR8_USER_PWD: 'XXXYYYZZZ'
	PR8_ROOT_PWD: 'ZZZYYYXXX'
```

Edit the `setup.yaml` to remove the above variable definitions, but instead add next to the `vars` definition:

```yaml
vars_files:
  - pr8-vault.yaml
```

In order to decrypt the vault, the command lines need to change somewhat. For example:

```shell
$ ansible-playbook -i hosts  enable-root.yaml
$ ansible-playbook -i hosts -k setup.yaml --ask-vault-pass  # Need to enter both root password and vault password
$ ansible-playbook -i hosts configure.yaml --ask-vault-pass
```

Of course, now it is time to change my passwords :-)

```shell
$ ansible-vault edit pr8-vault.yaml
$ ansible-playbook -i hosts -k setup.yaml --ask-vault-pass
# login with old SSH password. Will fail halfway through due to the password changing. Run it again with the new SSH pwd.
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



# Notes for later documentation

Login to a user account from a sudo user:
sudo -u homeassistant -H -s
