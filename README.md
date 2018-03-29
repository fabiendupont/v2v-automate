# V2V - Automate

This repository holds Automate code for the V2V project.

__WARNING__ - The examples below consider that you are running an appliance, not from source code.

There are two options to import the domain.

1. Import as Git backend domain. It requires _Git Repositories Owner_ role to be enabled on the appliance.

```
# cd /var/www/miq/vmdb
# bundle exec rake evm:automate:import GIT_URL=https://github.com/fdupont-redhat/v2v-automate.git PREVIEW=false ENABLED=true
```

2. Import from a exported ZIP file.

```
# curl -o /tmp/v2v-automate-master.zip https://codeload.github.com/fdupont-redhat/v2v-automate/zip/master
# cd /tmp/
# unzip v2v-automate-master.zip
# cd /var/www/miq/vmdb
# bundle exec rake evm:automate:import DOMAIN=V2V IMPORT_DIR=/tmp/v2v-automate-master PREVIEW=false ENABLED=true
```

Unless you want to contribute to this domain, you probably only need the Git backed approach.
