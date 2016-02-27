Micro PAAS
==========

Micro Declarative PAAS System

Want to duplicate a machine? Easy! Everything is in configuration files!

Minimum system intrusion for a PAAS system. Nix installs everything automatically.

Write your own plug-in.

Micro PAAS can be run without root if using ports above 1024.

Do not like it? Copy your Dockerfile-s, docker-compose-${name}.yml files and you can switch, fast.


Requirements
------------

- Linux machine
- Nix
- Docker


Technologies
------------

- Docker
- Docker Compose
- Nix
- Supervisord


Usage
-----

Get the code
```bash
git clone git://github.com/matejc/upaas.git
cd upaas
```

Install to /var/upass folder, everything required will be there so make the folder and set write permissions for used user
```bash
./install.sh
```

Now you are going to need `config.nix` and `stack.nix` (take a look in the repository for examples). Inside stack.nix, compose object is actually comparable to docker-compose - the same options, or if you prefer you can use `composeFile` instead to specify absolute path to the regular `docker-compose.yml` file.

To rebuild (build and rerun changed services) from your configuration file, use this command, the path to configuration file has to be absolute
```
upaas-rebuild `pwd`/config.nix
```

This should be it.

Oh yea, one more thing, to have this persistent after reboot, add `/home/<you>/.nix-profile/bin/upaas-start` to cron or something.


Limits
------

- no multi machine scaling

To do
-----

- integrate Nix rollbacks (for configurations)
