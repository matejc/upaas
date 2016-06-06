{ pkgs, vars }:
rec {
    searxOne = {
        enable = true;
        autostart = true;
        compose = {
            searx-one = {
                image = "searx:master";
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
    wordpress1 = {
        enable = true;
        autostart = true;
        compose = {
            wordpress = {
                image = "wordpress";
                links = ["database4:mysql"];
                ports = ["8008:80"];
            };
            database4 = {
                image = "mariadb";
                environment = {
                    MYSQL_ROOT_PASSWORD = "example";
                };
            };
        };
    };
}
