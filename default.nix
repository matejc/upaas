{
  pkgs ? import <nixpkgs> {}
, lib ? pkgs.lib
, stdenv ? pkgs.stdenv
, file ? ./stack.nix
, dataDir ? "/var/docker-compose"
}:
let
  runAsCurrentUser = script:
    stdenv.mkDerivation {
      name = "docker-compose";
      buildInputs = [ pkgs.docker pkgs.python27Packages.docker_compose ];
      shellHook = ''
        set -e
        ${script}
        exit $?
      '';
    };

  compose = file:
    import ./compose.nix { inherit pkgs file; };

  composeFromObject = object:
    import ./compose.nix { inherit pkgs object; };

  filter = v:
    if builtins.hasAttr "enable" v then v.enable else true;

  generate = file:
    let
      composes = lib.filter (v: filter v) (import file { inherit pkgs; });
    in
      map (c: {name = c.name; yml = composeFromObject c.compose;}) composes;

  buildAll = file:
    let
      manifest = generate file;
      manifestFile = manifestFileFun manifest;
    in
      runAsCurrentUser (
        (
          lib.concatMapStringsSep
          "\n"
          (c: ''
            docker-compose -f ${c.yml} build --pull
            ln -sf '${c.yml}' '${dataDir}/${c.name}.yml'
          '')
          manifest
        ) + ''

          ln -sf '${manifestFile}' '${dataDir}/manifest.json'
        ''
      );

  manifestFileFun = manifest:
    pkgs.writeText "docker-compose-manifest.json" (builtins.toJSON manifest);
in
  buildAll file
