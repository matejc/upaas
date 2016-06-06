{ git2docker ? { outPath = ./.; name = "git2docker"; }
, pkgs ? import <nixpkgs> {}
}:
let
  nodePackages = import "${pkgs.path}/pkgs/top-level/node-packages.nix" {
    inherit pkgs;
    inherit (pkgs) stdenv nodejs fetchurl fetchgit;
    neededNatives = [ pkgs.python ] ++ pkgs.lib.optional pkgs.stdenv.isLinux pkgs.utillinux;
    self = nodePackages;
    generated = ./output.nix;
  };
in rec {
  tarball = pkgs.runCommand "git2docker-0.0.1.tgz" { buildInputs = [ pkgs.nodejs ]; } ''
    mv `HOME=$PWD npm pack ${git2docker}` $out
  '';
  build = nodePackages.buildNodePackage {
    name = "git2docker-0.0.1";
    src = [ tarball ];
    buildInputs = nodePackages.nativeDeps."git2docker" or [];
    deps = [ nodePackages.by-spec."always-tail"."0.2.0" nodePackages.by-spec."basic-auth"."1.0.4" nodePackages.by-spec."bcrypt"."0.8.6" nodePackages.by-spec."pushover"."1.3.6" ];
    peerDependencies = [];
  };
}