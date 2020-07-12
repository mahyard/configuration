#!/bin/bash
##
## Installs the pre-requisites for running Open edX on a single Ubuntu 16.04
## instance.  This script is provided as a convenience and any of these
## steps could be executed manually.
##
## Note that this script requires that you have the ability to run
## commands as root via sudo.  Caveat Emptor!
##

##
## Sanity checks
##

if [[ ! $OPENEDX_RELEASE ]]; then
    echo "You must define OPENEDX_RELEASE"
    exit
fi

if [[ `lsb_release -rs` != "16.04" ]]; then
    echo "This script is only known to work on Ubuntu 16.04, exiting..."
    exit
fi

##
## Log what's happening
##

mkdir -p logs
log_file=logs/install-$(date +%Y%m%d-%H%M%S).log
exec > >(tee $log_file) 2>&1
echo "Capturing output to $log_file"
echo "Installation started at $(date '+%Y-%m-%d %H:%M:%S')"

function finish {
    echo "Installation finished at $(date '+%Y-%m-%d %H:%M:%S')"
}
trap finish EXIT

echo "Installing release '$OPENEDX_RELEASE'"

##
## Update and Upgrade apt packages
##
sudo apt-get update -y
sudo apt-get upgrade -y

##
## Install system pre-requisites
##
sudo apt-get install -y build-essential software-properties-common curl git python-pip python-apt

# my-passwords.yml is the file made by generate-passwords.sh.
if [[ -f my-passwords.yml ]]; then
    EXTRA_VARS="-e@$(pwd)/my-passwords.yml $EXTRA_VARS"
fi

CONFIGURATION_VERSION=$OPENEDX_RELEASE

##
## Clone the configuration repository and run Ansible
##
cd /var/tmp
git clone https://github.com/mahyard/configuration.git
cd configuration
git checkout $CONFIGURATION_VERSION
git pull

##
## Install the ansible requirements
##
sudo -H pip install -r requirements.txt

##
## Run the edx_sandbox.yml playbook in the configuration/playbooks directory
##
cd /var/tmp/configuration/playbooks && sudo -E ansible-playbook -c local ./gtc-persistance.yml -i "localhost," $EXTRA_VARS "$@"
ansible_status=$?

if [[ $ansible_status -ne 0 ]]; then
    echo " "
    echo "========================================"
    echo "Ansible failed!"
    echo "----------------------------------------"
    echo "If you need help, see https://open.edx.org/getting-help ."
    echo "When asking for help, please provide as much information as you can."
    echo "These might be helpful:"
    echo "    Your log file is at $log_file"
    echo "    Your environment:"
    env | egrep -i 'version|release' | sed -e 's/^/        /'
    echo "========================================"
fi
