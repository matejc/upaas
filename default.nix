{
  pkgs ? import <nixpkgs> {}
, lib ? pkgs.lib
, stdenv ? pkgs.stdenv
, prefix ? "upaas"
, configFile ? ./config.nix
, dataDir ? "/var/${prefix}"
, profileDir ? "${dataDir}/profile"
, docker_compose ? pkgs.python27Packages.docker_compose
, supervisor ? pkgs.python27Packages.supervisor
, nix ? pkgs.nix
, shell ? "${pkgs.bashInteractive}/bin/bash"
, user
}:
with import ./lib.nix { inherit pkgs; };
let
    config = import configFile { inherit pkgs; };
    stack = import config.stack { inherit pkgs; inherit (config) vars; };
    plugins = import ./plugins.nix {
        inherit pkgs config dataDir loggerPort;
    };
    loggerPort = if config ? loggerPort then config.loggerPort else "2000";

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
        lib.mapAttrsToList (n: c: rec {
            name = n;
            yml = getComposeYml n c;
            autostart = c.autostart || false;
            hash = unique yml;
        }) composes;

    writeScript = name: script:
        pkgs.writeScriptBin "${name}" ''
            #!${stdenv.shell} -e
            export PATH="${pkgs.busybox}/bin:$PATH"

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

    shellrc =
        pkgs.writeText "shellrc" ''
            export PS1="> "
            profile_commands="`ls -1 $PROFILE`"
            complete -E -W "$profile_commands"
            export PATH=$PROFILE
        '';

    shellScript =
        writeScript "${prefix}-shell" ''
            PROFILE="${profileDir}/build/bin"
            export PROFILE

            EXTRA="''$*"
            if [[ -n "$EXTRA" ]]; then
                EXTRA="-c \"$EXTRA\""
            fi

            PATH="$PROFILE:${pkgs.busybox}/bin" ${shell} --rcfile ${shellrc} $EXTRA
        '';

    startScript =
        writeScript "${prefix}-start" ''
            mkdir -p ${dataDir}/logs
            test -f ${profileDir}/build/share/supervisor.conf
            ${supervisor}/bin/supervisord -c ${profileDir}/build/share/supervisor.conf
        '';

    stopScript =
        writeScript "${prefix}-stop" ''
            test -f ${dataDir}/supervisord.pid
            kill -INT $(cat ${dataDir}/supervisord.pid)
        '';

    restartScript =
        writeScript "${prefix}-restart" ''
            test -f ${dataDir}/supervisord.pid
            kill -HUP $(cat ${dataDir}/supervisord.pid)
        '';

    supervisorLogScript =
        writeScript "${prefix}-log" ''
            test -f ${dataDir}/logs/supervisord.log
            tail -f ${dataDir}/logs/supervisord.log
        '';

    logScript = e: supervisorConf:
        writeScript "log-${e.name}" ''
            ${supervisor}/bin/supervisorctl -c ${supervisorConf} tail -f stack:${e.name}
        '';

    rebuildScript =
        writeScript "${prefix}-rebuild" ''
            mkdir -p ${profileDir}

            PATH="${profileDir}/build/bin:$PATH"
            CONFIG="$1"

            test -f $CONFIG || { echo "You must specify existing config file as first argument!"; false; }

            nix-env -f "${dataDir}/src/default.nix" -A build -i \
                -p ${profileDir}/build \
                --argstr user "`id -un`" \
                --argstr configFile "$CONFIG"

            ${profileDir}/build/bin/build-all || { "Build failed!"; false; }

            if [ -S ${dataDir}/supervisor.sock ]; then
                ${profileDir}/build/bin/update-all || { "Update failed!"; false; }
            else
                ${prefix}-start || { "Start failed!"; false; }
            fi

            echo "Done!"
        '';

    updateAllScript = plugins: supervisorConf:
        writeScript "update-all" ((
            lib.concatMapStringsSep
            "\n"
            (e: e.test)
            plugins
        ) + ''

            ${supervisor}/bin/supervisorctl -c ${supervisorConf} update || echo "Have you forgot to run 'upaas-start'?"
        '');

    makeBuild =
    let
        manifest = generate;
        manifestFile = manifestFileFun manifest;
        supervisorConf = supervisorConfFun manifest;
    in
        stdenv.mkDerivation rec {
            name = "${prefix}-build";
            buildInputs = [ pkgs.makeWrapper ];
            buildCommand = (''
                mkdir -p $out/{bin,share}
                ln -s ${manifestFile} $out/share/manifest.json
                ln -s ${supervisorConf} $out/share/supervisor.conf

                makeWrapper \
                    ${supervisor}/bin/supervisorctl \
                    $out/bin/ctl \
                    --add-flags "-c ${supervisorConf}"

                ln -s ${writeScript "containers-garbage-collect" "docker rm $(docker ps -q -f status=exited)"}/bin/* $out/bin
                ln -s ${writeScript "images-garbage-collect" "docker rmi $(docker images -q -f dangling=true)"}/bin/* $out/bin

                ln -s ${buildAllScript manifest}/bin/* $out/bin

                ln -s ${updateAllScript plugins supervisorConf}/bin/* $out/bin

            '' + (
                lib.concatMapStringsSep
                "\n"
                (e: ''
                    ln -s ${e.yml} $out/share/docker-compose-${e.name}.yml
                    ln -s ${buildScript e}/bin/* $out/bin
                    ln -s ${logScript e supervisorConf}/bin/* $out/bin
                '')
                manifest
            ));
        };

    manifestFileFun = manifest:
        pkgs.writeText "${prefix}-manifest.json" (builtins.toJSON manifest);

    supervisorConfFun = manifest:
        pkgs.writeText "supervisor.conf" (''
            [unix_http_server]
            file=${dataDir}/supervisor.sock
            chown=${user}

            [supervisord]
            logfile=${dataDir}/logs/supervisord.log
            pidfile=${dataDir}/supervisord.pid

            [supervisorctl]
            serverurl=unix://${dataDir}/supervisor.sock

            [rpcinterface:supervisor]
            supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

            [group:plugins]
            programs=${lib.concatMapStringsSep "," (e: e.name) plugins}
            priority=3

            [group:maintenance]
            programs=logger
            priority=2

            [group:stack]
            programs=${lib.concatMapStringsSep "," (e: "${e.name}_${e.hash}") manifest}
            priority=1

            [program:logger]
            command=${pkgs.socat}/bin/socat -u UDP-RECV:${toString loggerPort} -
            stopsignal=INT
            user=${user}
            autorestart=true
            autostart=true
            redirect_stderr=true
            stdout_logfile=${dataDir}/logs/logger.log

            '' + (
                lib.concatMapStringsSep
                "\n"
                (e: ''
                    [program:${e.name}_${e.hash}]
                    command=${docker_compose}/bin/docker-compose -p '${e.name}' -f '${e.yml}' up
                    stopsignal=INT
                    stopwaitsecs=20
                    user=${user}
                    autorestart=true
                    autostart=${if e.autostart then "true" else "false"}
                    redirect_stderr=true
                    stdout_logfile=${dataDir}/logs/stack-${e.name}.log

                '') manifest
            ) + (
                lib.concatMapStringsSep
                "\n"
                (e: ''
                    [program:${e.name}]
                    ${e.service}
                '') plugins
            )
        );

    makeEnv =
        pkgs.buildEnv {
            name = "${prefix}-env";
            paths = [ shellScript startScript stopScript restartScript
                supervisorLogScript rebuildScript ];
        };

in rec {
    build = makeBuild;
    env = makeEnv;
}
