{ self, fetchurl, fetchgit ? null, lib }:

{
  by-spec."always-tail"."0.2.0" =
    self.by-version."always-tail"."0.2.0";
  by-version."always-tail"."0.2.0" = self.buildNodePackage {
    name = "always-tail-0.2.0";
    version = "0.2.0";
    bin = false;
    src = fetchurl {
      url = "https://registry.npmjs.org/always-tail/-/always-tail-0.2.0.tgz";
      name = "always-tail-0.2.0.tgz";
      sha1 = "339b1af44d50250aa07a0e87eccc3a24ec444ffe";
    };
    deps = {
      "debug-0.7.4" = self.by-version."debug"."0.7.4";
    };
    optionalDependencies = {
    };
    peerDependencies = [];
    os = [ ];
    cpu = [ ];
  };
  "always-tail" = self.by-version."always-tail"."0.2.0";
  by-spec."basic-auth"."1.0.4" =
    self.by-version."basic-auth"."1.0.4";
  by-version."basic-auth"."1.0.4" = self.buildNodePackage {
    name = "basic-auth-1.0.4";
    version = "1.0.4";
    bin = false;
    src = fetchurl {
      url = "https://registry.npmjs.org/basic-auth/-/basic-auth-1.0.4.tgz";
      name = "basic-auth-1.0.4.tgz";
      sha1 = "030935b01de7c9b94a824b29f3fccb750d3a5290";
    };
    deps = {
    };
    optionalDependencies = {
    };
    peerDependencies = [];
    os = [ ];
    cpu = [ ];
  };
  "basic-auth" = self.by-version."basic-auth"."1.0.4";
  by-spec."bcrypt"."0.8.6" =
    self.by-version."bcrypt"."0.8.6";
  by-version."bcrypt"."0.8.6" = self.buildNodePackage {
    name = "bcrypt-0.8.6";
    version = "0.8.6";
    bin = false;
    src = fetchurl {
      url = "https://registry.npmjs.org/bcrypt/-/bcrypt-0.8.6.tgz";
      name = "bcrypt-0.8.6.tgz";
      sha1 = "182164f7d5e1de94ddd797473efd48b57b1f04b4";
    };
    deps = {
      "bindings-1.2.1" = self.by-version."bindings"."1.2.1";
      "nan-2.2.1" = self.by-version."nan"."2.2.1";
    };
    optionalDependencies = {
    };
    peerDependencies = [];
    os = [ ];
    cpu = [ ];
  };
  "bcrypt" = self.by-version."bcrypt"."0.8.6";
  by-spec."bindings"."1.2.1" =
    self.by-version."bindings"."1.2.1";
  by-version."bindings"."1.2.1" = self.buildNodePackage {
    name = "bindings-1.2.1";
    version = "1.2.1";
    bin = false;
    src = fetchurl {
      url = "https://registry.npmjs.org/bindings/-/bindings-1.2.1.tgz";
      name = "bindings-1.2.1.tgz";
      sha1 = "14ad6113812d2d37d72e67b4cacb4bb726505f11";
    };
    deps = {
    };
    optionalDependencies = {
    };
    peerDependencies = [];
    os = [ ];
    cpu = [ ];
  };
  by-spec."debug"."~0.7.2" =
    self.by-version."debug"."0.7.4";
  by-version."debug"."0.7.4" = self.buildNodePackage {
    name = "debug-0.7.4";
    version = "0.7.4";
    bin = false;
    src = fetchurl {
      url = "https://registry.npmjs.org/debug/-/debug-0.7.4.tgz";
      name = "debug-0.7.4.tgz";
      sha1 = "06e1ea8082c2cb14e39806e22e2f6f757f92af39";
    };
    deps = {
    };
    optionalDependencies = {
    };
    peerDependencies = [];
    os = [ ];
    cpu = [ ];
  };
  by-spec."duplex-pipe"."~0.0.1" =
    self.by-version."duplex-pipe"."0.0.2";
  by-version."duplex-pipe"."0.0.2" = self.buildNodePackage {
    name = "duplex-pipe-0.0.2";
    version = "0.0.2";
    bin = false;
    src = fetchurl {
      url = "https://registry.npmjs.org/duplex-pipe/-/duplex-pipe-0.0.2.tgz";
      name = "duplex-pipe-0.0.2.tgz";
      sha1 = "726a49cba8af719f4ba3a014f188d9a1fe0c7c25";
    };
    deps = {
    };
    optionalDependencies = {
    };
    peerDependencies = [];
    os = [ ];
    cpu = [ ];
  };
  by-spec."http-duplex"."~0.0.2" =
    self.by-version."http-duplex"."0.0.2";
  by-version."http-duplex"."0.0.2" = self.buildNodePackage {
    name = "http-duplex-0.0.2";
    version = "0.0.2";
    bin = false;
    src = fetchurl {
      url = "https://registry.npmjs.org/http-duplex/-/http-duplex-0.0.2.tgz";
      name = "http-duplex-0.0.2.tgz";
      sha1 = "fe0260f16172de02491eae109f3af4a4a70460c0";
    };
    deps = {
      "inherits-1.0.2" = self.by-version."inherits"."1.0.2";
      "duplex-pipe-0.0.2" = self.by-version."duplex-pipe"."0.0.2";
    };
    optionalDependencies = {
    };
    peerDependencies = [];
    os = [ ];
    cpu = [ ];
  };
  by-spec."inherits"."^1.0.0" =
    self.by-version."inherits"."1.0.2";
  by-version."inherits"."1.0.2" = self.buildNodePackage {
    name = "inherits-1.0.2";
    version = "1.0.2";
    bin = false;
    src = fetchurl {
      url = "https://registry.npmjs.org/inherits/-/inherits-1.0.2.tgz";
      name = "inherits-1.0.2.tgz";
      sha1 = "ca4309dadee6b54cc0b8d247e8d7c7a0975bdc9b";
    };
    deps = {
    };
    optionalDependencies = {
    };
    peerDependencies = [];
    os = [ ];
    cpu = [ ];
  };
  by-spec."inherits"."~1.0.0" =
    self.by-version."inherits"."1.0.2";
  by-spec."mkdirp"."~0.3.4" =
    self.by-version."mkdirp"."0.3.5";
  by-version."mkdirp"."0.3.5" = self.buildNodePackage {
    name = "mkdirp-0.3.5";
    version = "0.3.5";
    bin = false;
    src = fetchurl {
      url = "https://registry.npmjs.org/mkdirp/-/mkdirp-0.3.5.tgz";
      name = "mkdirp-0.3.5.tgz";
      sha1 = "de3e5f8961c88c787ee1368df849ac4413eca8d7";
    };
    deps = {
    };
    optionalDependencies = {
    };
    peerDependencies = [];
    os = [ ];
    cpu = [ ];
  };
  by-spec."nan"."2.2.1" =
    self.by-version."nan"."2.2.1";
  by-version."nan"."2.2.1" = self.buildNodePackage {
    name = "nan-2.2.1";
    version = "2.2.1";
    bin = false;
    src = fetchurl {
      url = "https://registry.npmjs.org/nan/-/nan-2.2.1.tgz";
      name = "nan-2.2.1.tgz";
      sha1 = "d68693f6b34bb41d66bc68b3a4f9defc79d7149b";
    };
    deps = {
    };
    optionalDependencies = {
    };
    peerDependencies = [];
    os = [ ];
    cpu = [ ];
  };
  by-spec."pushover"."1.3.6" =
    self.by-version."pushover"."1.3.6";
  by-version."pushover"."1.3.6" = self.buildNodePackage {
    name = "pushover-1.3.6";
    version = "1.3.6";
    bin = false;
    src = fetchurl {
      url = "https://registry.npmjs.org/pushover/-/pushover-1.3.6.tgz";
      name = "pushover-1.3.6.tgz";
      sha1 = "c168ebeb8ba05719028afe5cea1185b4cc7e6d72";
    };
    deps = {
      "http-duplex-0.0.2" = self.by-version."http-duplex"."0.0.2";
      "through-2.2.7" = self.by-version."through"."2.2.7";
      "inherits-1.0.2" = self.by-version."inherits"."1.0.2";
      "mkdirp-0.3.5" = self.by-version."mkdirp"."0.3.5";
    };
    optionalDependencies = {
    };
    peerDependencies = [];
    os = [ ];
    cpu = [ ];
  };
  "pushover" = self.by-version."pushover"."1.3.6";
  by-spec."through"."~2.2.7" =
    self.by-version."through"."2.2.7";
  by-version."through"."2.2.7" = self.buildNodePackage {
    name = "through-2.2.7";
    version = "2.2.7";
    bin = false;
    src = fetchurl {
      url = "https://registry.npmjs.org/through/-/through-2.2.7.tgz";
      name = "through-2.2.7.tgz";
      sha1 = "6e8e21200191d4eb6a99f6f010df46aa1c6eb2bd";
    };
    deps = {
    };
    optionalDependencies = {
    };
    peerDependencies = [];
    os = [ ];
    cpu = [ ];
  };
}
