{
  description = ''
    A nix configuration of a SLURM-based HPC cluster.
  '';

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    sops-nix.url = "github:Mic92/sops-nix";
    nixinate.url = "github:matthewcroughan/nixinate";
  };

  outputs = { self, nixpkgs, sops-nix, nixinate }@inputs:
    let lib = nixpkgs.lib;
    in {
      apps.x86_64-linux =
        (lib.mapAttrs' (name: value: lib.nameValuePair "nixinate-${name}" value)
          (nixinate.nixinate.x86_64-linux self).nixinate) // (lib.mapAttrs'
            (name: value:
              lib.nameValuePair "test-interactive-${name}" {
                type = "app";
                program = "${value.driverInteractive}/bin/nixos-test-driver";
              }) self.checks.x86_64-linux);

      nixosModules = let
        folder = ./modules;
        filterModules = key: value:
          value == "regular" && lib.hasSuffix ".nix" key;
      in lib.mapAttrs' (n: _:
        lib.nameValuePair (lib.removeSuffix ".nix" n)
        (import (folder + ("/" + n))))
      (lib.filterAttrs (filterModules) (builtins.readDir folder));

      nixosConfigurations = import ./hosts.nix inputs;

      checks.x86_64-linux = import ./tests.nix {
        inherit self nixpkgs;
        system = "x86_64-linux";
      };
    };
}
