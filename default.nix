{
  pkgs ? import <nixpkgs> {}
, lib ? pkgs.lib
, stdenv ? pkgs.stdenv
, prefix ? "mini-paas"
, configFile ? ./config.nix
, stateDir ? "/var/${prefix}"
, docker_compose ? pkgs.python27Packages.docker_compose
, supervisor ? pkgs.python27Packages.supervisor
}:
with import ./lib.nix { inherit pkgs; };
let
  config = import configFile { inherit pkgs; };
  stack = import config.stack { inherit pkgs; inherit (config) vars; };
  user = config.user;
  plugins = import ./plugins.nix {
    inherit pkgs config stateDir;
  };

  compose = name: containers:
    import ./compose.nix { inherit pkgs name containers; };

  getComposeYml = name: c:
    if c ? composeFile then
      { outPath = c.composeFile; name = "docker-compose-${name}.yml"; }
    else if c ? compose then
      compose name c.compose
    else
      builtins.throw "No composeFile and compose defined at ${name}!";

  generate =
    let
      composes = enabledAttrs stack;
    in
      lib.mapAttrsToList (n: c: {
          name = n;
          yml = getComposeYml n c;
          autostart = c.autostart || false;
      }) composes;

  writeScript = name: script:
    pkgs.writeScriptBin "${prefix}-${name}" ''
      #!${stdenv.shell} -e

      ${script}
    '';

  buildAllScript = manifest:
    writeScript "build-all" (
      lib.concatMapStringsSep
      "\n"
      (e: "${buildScript e}/bin/*")
      manifest
    );

  buildScript = e:
    writeScript "build-${e.name}" ''
      ${docker_compose}/bin/docker-compose -f '${e.yml}' build --pull
    '';

  logScript = e:
    writeScript "log-${e.name}" ''
      tail -f '${stateDir}/${prefix}-${e.name}.log'
    '';

  makeEnv =
    let
      manifest = generate;
      manifestFile = manifestFileFun manifest;
      supervisorConf = supervisorConfFun manifest;
    in
      stdenv.mkDerivation rec {
        name = "${prefix}-env";
        buildInputs = [ pkgs.makeWrapper ];
        buildCommand = (''
          mkdir -p $out/{bin,share}
          ln -s ${manifestFile} $out/share/manifest.json
          echo ${supervisorConf}
          ln -s ${supervisorConf} $out/share/supervisor.conf
          makeWrapper \
            ${supervisor}/bin/supervisord \
            $out/bin/${prefix}-supervisord-init \
            --add-flags "-c ${supervisorConf}"

          makeWrapper \
            ${supervisor}/bin/supervisorctl \
            $out/bin/${prefix}-supervisorctl \
            --add-flags "-c ${supervisorConf}"

          ln -s ${writeScript "supervisord-kill" "kill -INT $(cat ${stateDir}/supervisord.pid)"}/bin/* $out/bin
          ln -s ${writeScript "supervisord-reload" "kill -HUP $(cat ${stateDir}/supervisord.pid)"}/bin/* $out/bin
          ln -s ${writeScript "supervisord-log" "tail -f ${stateDir}/supervisord.log"}/bin/* $out/bin

          ln -s ${writeScript "containers-garbage-collect" "docker rm $(docker ps -q -f status=exited)"}/bin/* $out/bin
          ln -s ${writeScript "images-garbage-collect" "docker rmi $(docker images -q -f dangling=true)"}/bin/* $out/bin

          ln -s ${buildAllScript manifest}/bin/* $out/bin

        '' + (
          lib.concatMapStringsSep
          "\n"
          (e: ''
            ln -s ${e.yml} $out/share/docker-compose-${e.name}.yml
            ln -s ${buildScript e}/bin/* $out/bin
            ln -s ${logScript e}/bin/* $out/bin
          '')
          manifest
        ));
      };

  manifestFileFun = manifest:
    pkgs.writeText "${prefix}-manifest.json" (builtins.toJSON manifest);

  supervisorConfFun = manifest:
    pkgs.writeText "supervisor.conf" (''
      [unix_http_server]
      file=${stateDir}/supervisor.sock
      chown=${user}:nogroup

      [supervisord]
      logfile=${stateDir}/supervisord.log
      pidfile=${stateDir}/supervisord.pid

      [supervisorctl]
      serverurl=unix://${stateDir}/supervisor.sock

      [rpcinterface:supervisor]
      supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

      [group:plugins]
      programs=${lib.concatMapStringsSep "," (e: "plugin-${e.name}") plugins}
      priority=2

      [group:stack]
      programs=${lib.concatMapStringsSep "," (e: e.name) manifest}
      priority=1

    '' + (
      lib.concatMapStringsSep
      "\n"
      (e: ''
        [program:${e.name}]
        command=${docker_compose}/bin/docker-compose -p '${e.name}' -f '${e.yml}' up
        stopsignal=INT
        stopwaitsecs=20
        user=${user}
        autorestart=true
        autostart=${if e.autostart then "true" else "false"}
        redirect_stderr=true
        stdout_logfile=${stateDir}/logs/stack-${e.name}.log

      '') manifest) + (
      lib.concatMapStringsSep
      "\n"
      (e: ''
        [program:plugin-${e.name}]
        ${e.service}
      '') plugins)
    );

in
  makeEnv
