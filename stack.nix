{ pkgs, vars }:
rec {
    searxOne = {
        enable = true;
        autostart = false;
        compose = {
            searx-one = {
                build = vars.searxPath;
                ports = [
                    "7777:8888"
                ];
            };
        };
    };
    searxTwo = {
        enable = true;
        autostart = true;
        compose = {
            searx-two = {
                build = vars.searxPath;
                ports = [
                    "7778:8888"
                ];
            };
        };
    };
}
