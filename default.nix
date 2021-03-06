{
  pkgs ? import <nixpkgs> {}
, lib ? pkgs.lib
, stdenv ? pkgs.stdenv
, prefix ? "upaas"
, configFile ? ./config.nix
, dataDir ? "/var/${prefix}"
, profileDir ? "${dataDir}/profile"
, docker_compose ? pkgs.docker_compose
, supervisor ? pkgs.python3Packages.supervisor
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
    stackUser = if config ? stackUser then config.stackUser else user;
    loggerUser = if config ? loggerUser then config.loggerUser else user;

    compose = name: containers:
        import ./compose.nix { inherit pkgs name containers; };

    getComposeYml = name: c:
        if c ? composeFile then
            { outPath = c.composeFile; name = "docker-compose-${name}.yml"; }
        else if c ? compose then
            compose name c.compose
        else
            builtins.throw "No composeFile or compose defined at ${name}!";

    generate =
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
        pkgs.writeScriptBin "${name}" ''
            #!${shell} -e
            export PATH="${pkgs.busybox}/bin:$PATH"

            test -v DEBUG && set -x

            ${script}
        '';

    buildAllScript = manifest:
        writeScript "build-all" (
            concatMapAttrsStringsSep
            "\n"
            (n: e: "${buildScript e}/bin/*")
            manifest
        );

    buildScript = e:
        writeScript "build-${e.name}" ''
            if [[ "${e.hash}" == "${uniqueFromManifest e.name "${dataDir}/.previous.manifest.json"}" ]]
            then
                echo "Skip build of ${e.name}.";
            else
                echo "Building ${e.name} ...";
                ${docker_compose}/bin/docker-compose -f '${e.yml}' build
            fi
        '';

    updateScript = e: supervisorConf:
        writeScript "update-${e.name}" ''
            ${buildScript e}/bin/*
            ${restartStackScript e supervisorConf}/bin/*
        '';

    restartStackScript = e: supervisorConf:
        writeScript "restart-${e.name}" ''
            echo "Restarting ${e.name} ..."
            ${supervisor}/bin/supervisorctl -c ${supervisorConf} restart stack-${e.name}
        '';

    stopStackScript = e: supervisorConf:
        writeScript "stop-${e.name}" ''
            echo "Stop ${e.name} ..."
            ${supervisor}/bin/supervisorctl -c ${supervisorConf} stop stack-${e.name}
        '';

    startStackScript = e: supervisorConf:
        writeScript "start-${e.name}" ''
            echo "Start ${e.name} ..."
            ${supervisor}/bin/supervisorctl -c ${supervisorConf} start stack-${e.name}
        '';

    shellrc =
        pkgs.writeText "shellrc" ''
            export PS1="> "

            profile_commands="`ls -1 $PROFILE`"
            complete -E -W "$profile_commands"

            LS_CMD="`which ls`"
            function _list_logs {
                COMPREPLY=($(compgen -W "`$LS_CMD -1 ${dataDir}/logs`" -- "''${COMP_WORDS[COMP_CWORD]}"))
            }
            complete -F _list_logs log

            export PATH=$PROFILE
        '';

    shellScript =
        writeScript "${prefix}-shell" ''
            PROFILE="${profileDir}/build/bin"
            export PROFILE

            if [[ "x$@" == "x" ]]
            then
                PATH="$PROFILE:${pkgs.busybox}/bin" ${shell} --rcfile ${shellrc}
            else
                echo "'$@'" | PATH="$PROFILE:${pkgs.busybox}/bin" xargs ${shell} --rcfile ${shellrc} -c
            fi
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

    logScript =
        writeScript "log" ''
            test -f "${dataDir}/logs/$@"
            tail -f "${dataDir}/logs/$@"
        '';

    rebuildScript =
        writeScript "${prefix}-rebuild" ''
            mkdir -p ${profileDir}

            PATH="${profileDir}/build/bin:$PATH"
            CONFIG="$1"

            test -f $CONFIG || { echo "You must specify existing config file as first argument!"; false; }

            test -f ${profileDir}/build/share/manifest.json || echo '{}' > ${dataDir}/.previous.manifest.json

            nix-env -f "${dataDir}/src/default.nix" -A build -i \
                -p ${profileDir}/build \
                --argstr user "`id -un`" \
                --argstr configFile "$CONFIG" \
                --show-trace

            ${profileDir}/build/bin/build-all || { echo "Build failed!"; echo '{}' > ${dataDir}/.previous.manifest.json; false; }

            if [ -S ${dataDir}/supervisor.sock ]; then
                ${profileDir}/build/bin/update-all || { echo "Update failed!"; false; }
            else
                ${prefix}-start || { echo "Start failed!"; false; }
            fi

            test -f ${profileDir}/build/share/manifest.json && cp -f ${profileDir}/build/share/manifest.json ${dataDir}/.previous.manifest.json

            echo "Done!"
        '';

    updateAllScript = plugins: supervisorConf:
        writeScript "update-all" ((
            lib.concatMapStringsSep
            "\n"
            (e: "echo 'Running pre-start for plugin ${e.name}'\n${e.preStart}")
            plugins
        ) + ''

            ${supervisor}/bin/supervisorctl -c ${supervisorConf} update || { echo "Have you forgot to run 'upaas-start'?"; false; }
        '');

    makeBuild =
    let
        manifest = generate;
        manifestFile = manifestFileFun manifest;
        supervisorConf = supervisorConfFun manifest;
    in
        stdenv.mkDerivation {
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

                ln -s ${logScript}/bin/* $out/bin


            '' + (
                concatMapAttrsStringsSep
                "\n"
                (n: e: ''
                    ln -s ${e.yml} $out/share/docker-compose-${e.name}.yml
                    ln -s ${buildScript e}/bin/* $out/bin
                    ln -s ${restartStackScript e supervisorConf}/bin/* $out/bin
                    ln -s ${startStackScript e supervisorConf}/bin/* $out/bin
                    ln -s ${stopStackScript e supervisorConf}/bin/* $out/bin
                    ln -s ${updateScript e supervisorConf}/bin/* $out/bin
                '')
                manifest
            ));
        };

    manifestFileFun = manifest:
        pkgs.writeText "${prefix}-manifest.json" (builtins.toJSON
            manifest
        );

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

            [program:logger]
            command=${pkgs.socat}/bin/socat -u UDP-RECV:${toString loggerPort} -
            stopsignal=INT
            user=${loggerUser}
            autorestart=true
            autostart=true
            redirect_stderr=true
            stdout_logfile=${dataDir}/logs/logger.log

            '' + (
                concatMapAttrsStringsSep
                "\n"
                (n: e: ''
                    [program:stack-${e.name}]
                    command=${docker_compose}/bin/docker-compose -p '${e.name}' -f '${e.yml}' up
                    stopsignal=INT
                    stopwaitsecs=20
                    user=${stackUser}
                    autorestart=true
                    autostart=${if e.autostart then "true" else "false"}
                    redirect_stderr=true
                    stdout_logfile=${dataDir}/logs/stack-${e.name}.log
                    startsecs=10

                '') manifest
            ) + (
                lib.concatMapStringsSep
                "\n"
                (e: ''
                    [program:plugin-${e.name}]
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
