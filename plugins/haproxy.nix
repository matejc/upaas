{ pkgs, lib ? pkgs.lib, name, pluginConfig, user, vars, stateDir }:
with import ../lib.nix { inherit pkgs; };
let
    haproxyConf = pkgs.writeText "haproxy.conf" (''
        global
            maxconn 4096
            chroot ${stateDir}
            user ${user}
            group nogroup
            ${if pluginConfig ? extraGlobal then pluginConfig.extraGlobal else ""}

        defaults
            mode http
            timeout connect 10s
            timeout client  30s
            timeout server  30s
            balance roundrobin
            log global
            option httplog
            ${if pluginConfig ? extraDefault then pluginConfig.extraDefault else ""}
    ''
    +
    concatMapAttrsStringsSep "\n" (bind: v: ''
        frontend http_proxy_${unique bind}
            bind ${bind}
            ${concatMapAttrsStringsSep "\n" (domain: b:
                "acl is_${unique domain} hdr_dom(host) -i ${domain}"
            ) v}

            ${concatMapAttrsStringsSep "\n" (domain: backends:
                "use_backend cluster_${unique backends} if is_${unique domain}"
            ) v}

    '' + (concatMapAttrsStringsSep "\n" (d: backends: ''
        backend cluster_${unique backends}
        ${lib.concatImapStringsSep "\n" (i: backend:
            "    server server_${toString i} ${backend}"
        ) backends}
    '')
    ) v) pluginConfig.config);

    service = {
        command = "${pkgs.haproxy}/sbin/haproxy -f ${haproxyConf}";
        autostart = true;
        autorestart = true;
        user = "root";
    };
in {
    inherit service;
}


/*
config = {
    "127.0.0.1:9000" = {
        "localhost" = ["127.0.0.1:7777" "127.0.0.1:7778"];
    };
};
*/
