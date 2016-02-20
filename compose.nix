{ pkgs ? import <nixpkgs> {}
, containers ? null
, name ? null
, lib ? pkgs.lib }:
with import ./lib.nix { inherit pkgs; };
let
    any = name: value: level:
        ["${addPrefix level name}: ${toString value}"];

    int = any;

    path = any;

    bool = name: value: level:
        ["${addPrefix level name}: ${if value then "true" else "false"}"];

    string = name: value: level:
        ["${addPrefix level name}: \"${value}\""];

    list = name: value: level:  # TODO: nested
        (["${addPrefix level name}:"] ++ (map (entry: addPrefix (level+1) "- \"${toString entry}\"") value));

    attrs = name: value: level:
        ["${addPrefix level name}:"] ++ (lib.mapAttrsToList (n: v:
            getStrings n v (level+1)
        ) value);

    getStrings = n: v: level:
        if lib.isString v then string n v level
        else if lib.isInt v then int n v level
        else if lib.isBool v then bool n v level
        else if lib.isList v then list n v level
        else if (builtins.typeOf v) == "path" then path n v level
        else if lib.isAttrs v then attrs n v level
        else throw "Attribute with name ${n} has unsupported type (${builtins.typeOf v})!";

    containerLines = container:
        lib.mapAttrsToList (n: v:
            getStrings n v 1
        ) container;

    lines = lib.mapAttrsToList (name: container:
        ["${name}:"] ++ (containerLines container)
    ) containers;

    output = lib.concatStringsSep "\n" (lib.flatten lines);
in
    pkgs.writeText "docker-compose-${name}.yml" output
