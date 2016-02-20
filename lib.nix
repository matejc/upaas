{ pkgs, lib ? pkgs.lib }:
rec {
    isEnabled = v:
        if builtins.hasAttr "enable" v then v.enable else false;

    enabledAttrs = attrs:
        lib.filterAttrs (n: v: isEnabled v) attrs;

    addPrefix = level: str:
        let
            tabSize = 2;
            width = (level * tabSize) + (lib.stringLength str);
        in
            lib.fixedWidthString width " " str;

    programToString = name: service:
        import ./program.nix { inherit pkgs service name; };


    concatMapAttrsStringsSep = sep: f: attrs:
        lib.concatMapStringsSep sep (v: f v.name v.value) (lib.mapAttrsToList (n: v: lib.nameValuePair n v) attrs);

    unique = value:
        let
            str = builtins.hashString "sha1" (toString value);
        in
            lib.substring 0 10 str;
}
