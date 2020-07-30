#!/bin/bash
#
# create-users.sh - Small utility to help creating users accounts from a file given as parameter.
# The file must contain one user per line in the form firstname_lastname. 
# The script generates random password for each user. Once done, it outputs the list of user:password 
# in <users-output.txt>.
#
# usage: create-users.sh <users-list.txt>
#
# Caroline Monthoux - 07-07-2020

# check that the script is called as root
if [[ "$UID" != 0 ]]; then
        echo "Error: permission denied. Use sudo or run the script as root." >&2
        exit 1
fi

# check that a parameter is given
if [ -z "${1}" ] ;then
        echo "Usage: create-users.sh <users-list.txt>"
        exit 1
fi

list="${1}"
output="${list}-output.txt"

# create a user account for each name in the file
if [ -f $list ]; then
        while IFS= read -r user; do
                # generate a password (8 characters)
                password=$(pwgen -s -1 5)
                useradd --create-home --skel /etc/skelStudents --shell /bin/bash --groups student ${user}
				chown zabbix:zabbix /home/${user}/.monitoring/proxy_settings
				chmod o-r /home/${user}/.monitoring/proxy_settings
                echo "$user:$password" | chpasswd
                echo "$user:$password" >> ${output}
                echo "Created user ${user}."
        done < $list
        echo "Done. See ${output} for the passwords."
else
        echo "Error: parameter must be a file."
fi