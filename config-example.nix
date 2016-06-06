{ pkgs }:
rec {
    stack = ./stack-example.nix;
    user = "matejc";
    vars = {
        searxPath = /home/matejc/workarea/searx;
    };
    plugins = {
        haproxy = {
            enable = true;
            path = ./plugins/haproxy.nix;
            http = {
                "127.0.0.1:9000" = {
                    cert = /home/matejc/tmp/localhost.pem;
                    "localhost" = ["127.0.0.1:7777" "127.0.0.1:7778"];
                };
            };
            tcp = {
                "127.0.0.1:10000" = ["127.0.0.1:7777" "127.0.0.1:7778"];
            };
        };
        webhooks = {
            enable = true;
            path = ./plugins/webhooks.nix;
            listen = "8888";
            config = {
                upgradeSearx = {
                    key = "someVeryLongSecret";
                    cmd = [
                        "${pkgs.git}/bin/git -C ${vars.searxPath} status"
                        "update-searxOne"
                        "update-searxTwo"
                    ];
                };
            };
        };
        git2docker = {
            enable = true;
            path = ./plugins/git2docker/plugin.nix;
            listen = "10000";
            username = "git2docker";
            password = "someVeryLongSecret";
            config = {
                searx = {
                    branch = "master";
                    cmd = [
                        "update-searxOne"
                    ];
                };
            };
        };
    };
}
