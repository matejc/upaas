{ pkgs }:
[
    {
        name = "searxOne";
        enable = false;
        compose = [
          {
            name = "searx-one";
            build = /home/matejc/workarea/searx;
            ports = [
              "7777:8888"
            ];
          }
        ];
    }
    {
        name = "searxTwo";
        enable = false;
        compose = [
          {
            name = "searx-two";
            build = /home/matejc/workarea/searx;
            ports = [
              "7778:8888"
            ];
          }
        ];
    }
]
