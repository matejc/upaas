{ config, lib, pkgs, ... }:
with lib;
with import ./lib.nix { inherit pkgs; };
let
    cfg = config.services.upaas;
    stdenv = pkgs.stdenv;
    prefix = "upaas";
    dataDir = "/var/${prefix}";
    profileDir = "${dataDir}/profile";
    docker_compose = pkgs.docker-compose;
    supervisor = pkgs.python3Packages.supervisor;
    nix = pkgs.nix;
    shell = "${pkgs.bashInteractive}/bin/bash";
    user = cfg.user;

    configuration = (if builtins.typeOf cfg.configuration == "set" then cfg.configuration else import cfg.configuration { inherit pkgs; }) // { inherit user; };
    stack = if builtins.typeOf configuration.stack == "set" then configuration.stack else import configuration.stack { inherit pkgs; inherit (configuration) vars; };
    plugins = import ./plugins.nix {
        inherit pkgs dataDir loggerPort;
        config = configuration;
    };
    loggerPort = if configuration ? loggerPort then configuration.loggerPort else "2000";
    stackUser = if configuration ? stackUser then configuration.stackUser else user;
    loggerUser = if configuration ? loggerUser then configuration.loggerUser else user;

    compose = name: content:
        saveJSON "${name}.json" content;

    getComposeFile = name: c:
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
            file = getComposeFile n c;
            autostart = c.autostart || false;
            deps = if c ? deps then c.deps else [];
            hash = unique ([ n file ] ++ deps);
            directory = if c ? directory then c.directory else null;
            user = if c ? user then c.user else cfg.user;
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
      path = e.deps;
      serviceConfig = {
        User = e.user;
        ExecStart = writeScript "${prefix}-stack-${name}-start" "${docker_compose}/bin/docker-compose --ansi never --progress quiet -p '${e.name}' ${optionalString (e.directory != null) "--project-directory '${e.directory}'"} -f '${e.file}' up --build --no-color";
        ExecStop = writeScript "${prefix}-stack-${name}-stop" "${docker_compose}/bin/docker-compose --ansi never --progress quiet -p '${e.name}' ${optionalString (e.directory != null) "--project-directory '${e.directory}'"} -f '${e.file}' down";
        TimeoutStopSec = "20";
      };
    };
    stackServices = mapAttrs' (n: v: nameValuePair ("${prefix}-stack-" + n) (stackServiceFun n v)) manifest;

    dockerComposeScript = e:
        pkgs.writeScriptBin "${prefix}-compose-${e.name}" ''
            #!${pkgs.stdenv.shell}
            ${docker_compose}/bin/docker-compose -p '${e.name}' -f '${e.file}' "$@"
        '';

    logScript = e:
        pkgs.writeScriptBin "${prefix}-log-${e.name}" ''
            #!${pkgs.stdenv.shell}
            journalctl $1 -u ${prefix}-stack-${e.name}
        '';

    systemdScript = e:
        pkgs.writeScriptBin "${prefix}-systemctl-${e.name}" ''
            #!${pkgs.stdenv.shell}
            systemctl $1 ${prefix}-stack-${e.name}
        '';

        stackCommands = (mapAttrsToList (n: v: dockerComposeScript v) manifest) ++
          (mapAttrsToList (n: v: logScript v) manifest) ++
          (mapAttrsToList (n: v: systemdScript v) manifest);
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

        plugins = mkOption {
          type = types.bool;
          default = true;
          description = ''
            Enable uPAAS plugins.
          '';
        };

        configuration = mkOption {
          type = types.either types.attrs types.path;
          description = "Configuration or path.";
        };

        user = mkOption {
          type = types.str;
          default = "root";
          description = "User name.";
        };
      };
    };

    config = mkIf cfg.enable ({
      systemd.services = (optionalAttrs (cfg.plugins) ({ "${prefix}-logger" = loggerService; } // pluginServices)) // stackServices;
      environment.systemPackages = stackCommands;
    });
}
