{ pkgs, lib ? pkgs.lib, config, dataDir, loggerPort }:
with import ./lib.nix { inherit pkgs; };
let
    plugins = lib.mapAttrsToList (name: p:
        setupPlugin name (
            import p.path {
                pluginConfig = p;
                inherit (config) vars user;
                inherit pkgs name dataDir loggerPort;
            }
        )
    ) (enabledAttrs config.plugins);

    serviceDefaults = name: {
        user = config.user;
        redirect_stderr = true;
        stdout_logfile = "${dataDir}/logs/plugin-${name}.log";
    };

    setupPlugin = name: plugin:
    let
        service = programToString name ((serviceDefaults name) // plugin.service);
        hash = unique plugin.service.command;
    in {
        inherit name service hash;
        inherit (plugin) preStart;
    };
in
    plugins
