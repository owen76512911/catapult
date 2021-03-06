#!/usr/bin/env bash
# variables inbound from provisioner args
# $1 => environment
# $2 => repository
# $3 => gpg key
# $4 => instance



echo -e "\n\n\n==> SYSTEM INFORMATION"

# who are we?
hostnamectl status



echo -e "\n\n\n==> INSTALLING MINIMAL DEPENDENCIES"

# update packages
sudo yum update -y

# install git
sudo yum install -y git



echo -e "\n\n\n==> RECEIVING CATAPULT"

# what are we receiving?
echo -e "=> ENVIRONMENT: ${1}"
echo -e "=> REPOSITORY: ${2}"
echo -e "=> GPG KEY: ************"
echo -e "=> INSTANCE: ${4}"

# define the branch
if ([ $1 = "production" ]); then
    branch="master"
elif ([ $1 = "qc" ]); then
    branch="release"
else
    branch="develop"
fi
# get the catapult instance
if ([ $1 = "dev" ]); then
    # determine if the vagrant synced folder is working properly
    if ! [ -e "/catapult/secrets/configuration.yml.gpg" ]; then
        echo -e "Cannot read from /catapult/secrets/configuration.yml.gpg, please vagrant reload the virtual machine."
        exit 1
    else
        echo -e "Your Catapult instance is being synced from your host machine."
    fi
    # if there are changes between us and remote, write a changes file for later use
    cd "/catapult" && sudo git diff --exit-code --quiet
    if [ $? -eq 1 ]; then
        touch "/catapult/provisioners/redhat/logs/catapult.changes"
    fi
else
    # clone the catapultrepository if it does not exist
    if ! [ -d "/catapult/.git" ]; then
        sudo git clone --recursive --branch ${branch} $2 "/catapult"
    # if the catapult repository does exist
    else
        # accomodate for a change from https to ssh as the origin url
        cd "/catapult" && sudo git remote set-url origin $2
        # check out the defined branch
        cd "/catapult" \
            && sudo git reset --quiet --hard HEAD -- \
            && sudo git checkout . \
            && sudo git checkout ${branch} \
            && sudo git fetch
    fi
    # if there are changes between us and remote, write a changes file for later use
    cd "/catapult" && sudo git diff --exit-code --quiet ${branch} origin/${branch}
    if [ $? -eq 1 ]; then
        touch "/catapult/provisioners/redhat/logs/catapult.changes"
    fi
    # pull in the latest
    cd "/catapult" \
        && sudo git pull
fi
# override updates variable if this is a new machine
if [ ! -f "/catapult/provisioners/redhat/logs/${4}.log" ]; then
    touch "/catapult/provisioners/redhat/logs/catapult.changes"
fi





# that's a lot of catapult
echo -e "\n\n\n "
cat /catapult/catapult/catapult.txt
echo -e "\n "
version=$(cd /catapult && cat /catapult/VERSION.yml | grep "version:" | awk '{print $2}')
repo=$(cd /catapult && git config --get remote.origin.url)
branch=$(cd /catapult && git rev-parse --abbrev-ref HEAD)
echo -e "==> CATAPULT VERSION: ${version}"
echo -e "==> CATAPULT GIT REPO: ${repo}"
echo -e "==> GIT BRANCH: ${branch}"



echo -e "\n\n\n==> STARTING PROVISION"

# provision the server
bash "/catapult/provisioners/redhat/provision_server.sh" $1 $2 $3 $4
