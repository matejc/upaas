{ pkgs, lib ? pkgs.lib, config, dataDir, loggerPort }:
with import ./lib.nix { inherit pkgs; };
let
    plugins = lib.mapAttrsToList (name: p:
        let
            user = if p ? user then p.user else config.user;
        in
        setupPlugin name user (
            import p.path {
                pluginConfig = p;
                inherit (config) vars;
                inherit pkgs name dataDir loggerPort user;
            }
        )
    ) (enabledAttrs config.plugins);

    serviceDefaults = name: user: {
        inherit user;
        redirect_stderr = true;
        stdout_logfile = "${dataDir}/logs/plugin-${name}.log";
    };

    setupPlugin = name: user: plugin:
    let
        serviceOptions = (serviceDefaults name user) // plugin.service;
        service = programToString name options;
        hash = unique plugin.service.command;
    in {
        inherit name service hash serviceOptions;
        inherit (plugin) preStart;
    };
in
    plugins
