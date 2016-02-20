{ pkgs }:
rec {
    stack = ./stack.nix;
    user = "matejc";
    vars = {
        searxPath = /home/matejc/workarea/searx;
    };
    plugins = {
        haproxy = {
            enable = true;
            path = ./plugins/haproxy.nix;
            config = {
                "127.0.0.1:9000" = {
                    "localhost" = ["127.0.0.1:7777" "127.0.0.1:7778"];
                };
            };
        };
        webhooks = {
            enable = false;
            path = ./plugins/webhooks.nix;
            config = {
                upgrade-searx = {
                    key = "someVeryLongSecret";
                    cmd = [
                        "${pkgs.git}/bin/git -C ${vars.searxPath} pull"
                        "mini-paas-build-searxOne"
                        "mini-paas-build-searxTwo"
                        "mini-paas-supervisorctl update"
                    ];
                };
            };
        };
    };
}
