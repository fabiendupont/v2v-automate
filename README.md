# V2V - Automate

This repository holds Automate code for the V2V project.
Import can be done from the zip file:

```
$ curl -o /tmp/v2v-automate.zip https://codeload.github.com/fdupont-redhat/v2v-automate/zip/master
$ cd /home/miq/manageiq
$ bundle exec rake evm:automate:import DOMAIN=V2V ZIP_FILE=/tmp/v2v-automate.zip PREVIEW=false ENABLED=true
```
