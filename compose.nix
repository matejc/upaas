{ pkgs ? import <nixpkgs> {}
, file ? ./stack.nix
, object ? null
, lib ? pkgs.lib }:
let
  containers =
    if object == null then import file { inherit pkgs; }
    else object;

  prefix = level: str:
    let
      tabSize = 2;
      width = (level * tabSize) + (lib.stringLength str);
    in
      lib.fixedWidthString width " " str;

  path = name: container:
    lib.optionals
    (builtins.hasAttr name container)
    ["${prefix 1 name}: ${toString (builtins.getAttr name container)}"];

  string = name: container:
    lib.optionals
    (builtins.hasAttr name container)
    ["${prefix 1 name}: \"${toString (builtins.getAttr name container)}\""];

  list = name: container:
    lib.optionals
    (builtins.hasAttr name container)
    (["${prefix 1 name}:"] ++ (map (entry: prefix 2 "- \"${toString entry}\"") (builtins.getAttr name container)));

  containerLines = container:
    (lib.mapAttrsToList (n: v:
      if lib.isString v then string n container
      else if lib.isList v then list n container
      else if (builtins.typeOf v) == "path" then path n container
      else throw "Attribute with name ${n} has unsupported type (${builtins.typeOf v})!"
    ) (lib.filterAttrs (n: v: n != "name") container));

  exclude = v:
    if builtins.hasAttr "exclude" v then v.exclude else false;

  lines = map (container:
    ["${container.name}:"] ++ (containerLines container)
  ) containers;

  output = lib.concatStringsSep "\n" (lib.flatten lines);
in
  pkgs.writeText "docker-compose.yml" output
