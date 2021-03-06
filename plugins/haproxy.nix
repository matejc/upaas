{ pkgs, lib ? pkgs.lib, name, pluginConfig, user, vars, dataDir, loggerPort }:
with import ../lib.nix { inherit pkgs; };
let
    haproxyConf = pkgs.writeText "haproxy.conf" (''
        global
            log 127.0.0.1:${loggerPort} local0 notice
            tune.ssl.default-dh-param 2048
            ${if pluginConfig ? extraGlobal then pluginConfig.extraGlobal else ""}

        defaults
            timeout connect 10s
            timeout client  30s
            timeout server  30s
            balance roundrobin
            log global
            ${if pluginConfig ? extraDefaults then pluginConfig.extraDefaults else ""}
    ''
    +
    concatMapAttrsStringsSep "\n" (bind: v:
        let
            domains = lib.filterAttrs (n: a: n != "cert" && n != "extra") v;
            cert = if v ? cert then
                "ssl crt ${toString v.cert}"
                else "";
        in ''
        frontend http_proxy_${unique bind}
            bind ${bind} ${cert}
            mode http
            option httplog

        ${concatMapAttrsStringsSep "\n" (domain: b:
            "    acl is_${unique domain} hdr_dom(host) -i ${domain}"
        ) domains}

        ${concatMapAttrsStringsSep "\n" (domain: backends:
            "    use_backend cluster_${unique backends} if is_${unique domain}"
        ) domains}

            ${lib.optionalString (v ? extra) v.extra}

    '' + (concatMapAttrsStringsSep "\n" (d: backends: ''
        backend cluster_${unique backends}
            mode http
        ${lib.concatImapStringsSep "\n" (i: backend:
        "    server server_${toString i} ${backend}"
        ) backends}

    '')
    ) domains) (lib.optionalAttrs (pluginConfig?http) pluginConfig.http)
    +
    concatMapAttrsStringsSep "\n" (bind: backends:
        let
            id = unique ([bind]++backends);
        in ''
        frontend tcp_proxy_${id}
            mode tcp
            bind ${bind}
            option tcplog
            use_backend cluster_${id}

        backend cluster_${id}
            mode tcp
        ${lib.concatImapStringsSep "\n" (i: backend:
            "    server server_${toString i} ${backend}"
        ) backends}
    '') (lib.optionalAttrs (pluginConfig?tcp) pluginConfig.tcp)
    );

    service = {
        command = "${pkgs.haproxy}/sbin/haproxy -f ${haproxyConf}";
        autostart = true;
        autorestart = true;
    };

    preStart = ''
        ${pkgs.haproxy}/sbin/haproxy -f ${haproxyConf} -c
    '';
in {
    inherit service preStart;
}
