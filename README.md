# V2V - Automate

This repository holds Automate code for the V2V project.
Import can be done from the zip file:

```
$ curl -o /tmp/v2v-automate-master.zip https://codeload.github.com/fdupont-redhat/v2v-automate/zip/master
$ cd /tmp/
$ unzip v2v-ansible-master.zip
$ cd /home/miq/manageiq
$ bundle exec rake evm:automate:import DOMAIN=V2V IMPORT_DIR=/tmp/v2v-automate-master PREVIEW=false ENABLED=true
```
