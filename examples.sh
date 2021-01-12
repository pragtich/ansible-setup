#!/bin/bash

# after first flash of Armbian, ssh into the unit (check IP in router webinterface) root pwd: 1234
ansible-playbook -i hosts  enable-root.yaml
ansible-playbook -i hosts -k setup.yaml --ask-vault-pass  # Need to enter both root password and vault password
ansible-playbook -i hosts configure.yaml --ask-vault-pass
