{ config, lib, pkgs, ... }:
with lib;
with import ./lib.nix { inherit pkgs; };
let
    cfg = config.services.upaas;
    stdenv = pkgs.stdenv;
    prefix = "upaas";
    dataDir = "/var/${prefix}";
    profileDir = "${dataDir}/profile";
    docker_compose = pkgs.python27Packages.docker_compose;
    supervisor = pkgs.python27Packages.supervisor;
    nix = pkgs.nix;
    shell = "${pkgs.bashInteractive}/bin/bash";
    user = cfg.user;

    configuration = import cfg.configurationPath { inherit pkgs; } // { inherit user; };
    stack = import configuration.stack { inherit pkgs; inherit (configuration) vars; };
    plugins = import ./plugins.nix {
        inherit pkgs dataDir loggerPort;
        config = configuration;
    };
    loggerPort = if configuration ? loggerPort then configuration.loggerPort else "2000";
    stackUser = if configuration ? stackUser then configuration.stackUser else user;
    loggerUser = if configuration ? loggerUser then configuration.loggerUser else user;

    compose = name: containers:
        import ./compose.nix { inherit pkgs name containers; };

    getComposeYml = name: c:
        if c ? composeFile then
            { outPath = c.composeFile; name = "docker-compose-${name}.yml"; }
        else if c ? compose then
            compose name c.compose
        else
            builtins.throw "No composeFile or compose defined at ${name}!";

    manifest =
    let
        composes = enabledAttrs stack;
    in
        lib.mapAttrs (n: c: rec {
            name = n;
            yml = getComposeYml n c;
            autostart = c.autostart || false;
            hash = unique [ n yml ];
        }) composes;

    writeScript = name: script:
        pkgs.writeScript "${name}" ''
            #!${shell} -e
            export PATH="${pkgs.busybox}/bin:$PATH"

            test -v DEBUG && set -x

            ${script}
        '';

    loggerService =
    {
      description = "${prefix} logger";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "docker.service" ];
      requires = [ "docker.service" ];
      serviceConfig = {
        User = loggerUser;
        ExecStart = writeScript "${prefix}-logger-start" "${pkgs.socat}/bin/socat -u UDP-RECV:${toString loggerPort} -";
        KillSignal = "SIGINT";
        KillMode = "mixed";
        TimeoutStopSec = "10";
      };
    };

    pluginServiceFun = name: plugin:
    {
      description = "${prefix} plugin ${name}";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "docker.service" ];
      requires = [ "docker.service" ];
      environment = plugin.serviceOptions.environment or {};
      serviceConfig = {
        User = plugin.serviceOptions.user;
        ExecStartPre = writeScript "${prefix}-plugin-${name}-startPre" plugin.preStart;
        ExecStart = writeScript "${prefix}-plugin-${name}-start" plugin.serviceOptions.command;
        KillSignal = "SIGINT";
        KillMode = "mixed";
        TimeoutStopSec = "10";
      };
    };
    pluginServices = listToAttrs (map (v: nameValuePair ("${prefix}-plugin-" + v.name) (pluginServiceFun v.name v)) plugins);

    stackServiceFun = name: e:
    {
      description = "${prefix} stack ${name}";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "docker.service" ];
      requires = [ "docker.service" ];
      serviceConfig = {
        User = stackUser;
        ExecStart = writeScript "${prefix}-stack-${name}-start" "${docker_compose}/bin/docker-compose -p '${e.name}' -f '${e.yml}' up --build";
        ExecStop = writeScript "${prefix}-stack-${name}-stop" "${docker_compose}/bin/docker-compose -p '${e.name}' -f '${e.yml}' stop";
        TimeoutStopSec = "20";
      };
    };
    stackServices = mapAttrs' (n: v: nameValuePair ("${prefix}-stack-" + n) (stackServiceFun n v)) manifest;
in {
    options = {
      services.upaas = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Enable uPAAS.
          '';
        };

        configurationPath = mkOption {
          type = types.path;
          description = "Configuration file path.";
        };

        user = mkOption {
          type = types.str;
          default = "root";
          description = "User name.";
        };
      };
    };

    config = mkIf cfg.enable ({
      systemd.services = { "${prefix}-logger" = loggerService; } // pluginServices // stackServices;
    });
}
