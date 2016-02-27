{ pkgs ? import <nixpkgs> {}
, service
, name
, lib ? pkgs.lib }:
let
    any = name: value:
        ["${name}=${toString value}"];

    int = any;

    path = any;

    bool = name: value:
        ["${name}=${if value then "true" else "false"}"];

    string = any;

    list = name: value:
        [("${name}="+(lib.concatMapStringsSep "," (entry: "${toString entry}") value))];

    attrs = name: value:
        [("${name}="+(lib.concatStringsSep "," (lib.mapAttrsToList (n: v: "${n}=\"${toString v}\"") value)))];

    getStrings = n: v:
      if lib.isString v then string n v
      else if lib.isInt v then int n v
      else if lib.isBool v then bool n v
      else if lib.isList v then list n v
      else if (builtins.typeOf v) == "path" then path n v
      else if lib.isAttrs v then attrs n v
      else throw "Attribute with name ${n} has unsupported type (${builtins.typeOf v})!";

    lines =
      lib.mapAttrsToList (n: v: getStrings n v) service;

    output = lib.concatStringsSep "\n" (lib.flatten lines);
in
    output
