{ pkgs, lib ? pkgs.lib, name, pluginConfig, user, vars, dataDir, loggerPort }:
with import ../../lib.nix { inherit pkgs; };
let
    reposDir = "${dataDir}/src/plugins/git2docker/repos";
    logsDir = "${dataDir}/logs";

    optionsJSON = pkgs.writeText "options.json" ''
        {
            "username": "${pluginConfig.username}",
            "password": "${pluginConfig.password}",
            "repos": "${reposDir}",
            "logs": "${logsDir}",
            "port": ${toString pluginConfig.listen},
            "cmdPrefix": ""
        }
    '';

    repositoriesJSON = pkgs.writeText "repositories.json" (builtins.toJSON pluginConfig.config);

    node = pkgs.nodejs-4_x;

    path = lib.makeBinPath [ node pkgs.bash pkgs.git pkgs.coreutils pkgs.docker ];

    git2docker = (pkgs.callPackage ./. {}).build;

    service = {
        command = "${node}/bin/node run.js";
        directory = "${git2docker}/lib/node_modules/git2docker";
        environment = "PATH=${dataDir}/profile/build/bin:${path},OPTIONS_JSON=${optionsJSON},REPOSITORIES_JSON=${repositoriesJSON}";
        autostart = true;
        autorestart = true;
    };

    preStart = ''
        mkdir -p ${reposDir}
        mkdir -p ${logsDir}
    '';
in {
    inherit service preStart;
}
