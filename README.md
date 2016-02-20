Mini PAAS
=========

DO NOT USE IN PRODUCTION

Mini Declarative PAAS System

Want to duplicate a machine? Easy! Everything is in configuration files!

Minimum system intrusion for a PAAS system. Nix installs everything automatically.

Write your own plug-in.

Everything can be run without root if using ports above 1024.

Do not like it? Copy your Dockerfile-s, docker-compose-${name}.yml files and you can switch, fast.


Requirements
------------

- Linux machine
- Nix
- Docker


Technologies
------------

- Docker Compose
- Nix
- Supervisord


Limits
------

- no multi machine scaling
