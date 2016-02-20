{ pkgs, lib ? pkgs.lib, config, stateDir }:
with import ./lib.nix { inherit pkgs; };
let
    plugins = lib.mapAttrsToList (name: p:
        setupPlugin name (
            import p.path {
                pluginConfig = p;
                inherit (config) vars user;
                inherit pkgs name stateDir;
            }
        )
    ) (enabledAttrs config.plugins);

    serviceDefaults = name: {
        user = config.user;
        redirect_stderr = true;
        stdout_logfile = "${stateDir}/logs/plugin-${name}.log";
    };

    setupPlugin = name: plugin: {
        inherit name;
        service =
            programToString name ((serviceDefaults name) // plugin.service);
    };
in
    plugins
