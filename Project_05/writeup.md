# Project 5: Secure Linux Server Permissions

## Goal

Apply user-based access restrictions on Ubuntu.

## Implementation

1. Created the `p05_access` group and two users. Added `p05_allowed` to the group and left `p05_denied` out of it.

   `sudo groupadd p05_access`  
   `sudo useradd -m -s /bin/bash -G p05_access p05_allowed`  
   `sudo useradd -m -s /bin/bash p05_denied`

2. Created the project directory and a restricted file containing a test message.

   `sudo mkdir -m 0700 /srv/project_05`  
   `printf 'Project 5: authorized access only.\n' | sudo tee /srv/project_05/restricted.txt >/dev/null`

3. Set the directory and file owner to `root` and group to `p05_access`. Set the directory permissions to `750` and file permissions to `640`. This allows group members to enter the directory and read the file, but does not grant access to other users.

   `sudo chown root:p05_access /srv/project_05 /srv/project_05/restricted.txt`  
   `sudo chmod 750 /srv/project_05`  
   `sudo chmod 640 /srv/project_05/restricted.txt`

## Results

Tested file access as each user:

`sudo -u p05_allowed cat /srv/project_05/restricted.txt`  
`sudo -u p05_denied cat /srv/project_05/restricted.txt`

`p05_allowed` successfully read the file. `p05_denied` received a permission-denied error.

Evidence: [Access test screenshot](Screenshot%202026-11-23%20130954.png).