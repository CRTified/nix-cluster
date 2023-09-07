{ self, nixpkgs, sops-nix, ... }:
let
  lib = nixpkgs.lib;
  base = name: modules:
    nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { nodes = self.nixosConfigurations; };
      modules = with self.nixosModules;
        [
          ({ lib, ... }: {
            options.clusterRole = lib.mkOption {
              type = lib.types.anything;
              default = { };
            };
          })

          ({ config, ... }: {
            networking.hostName = name;
            _module.args.nixinate = {
              host = config.clusterRole.network.external.address;
              sshUser = "root";
              buildOn = "local";
              substituteOnTarget = false;
              hermetic = true;
            };
          })
          sops-nix.nixosModules.sops
          "${nixpkgs.outPath}/nixos/modules/virtualisation/qemu-vm.nix"
          common
          impureCompiler

          internalNetwork
          nfs

          slurmCommon
          munged
        ] ++ modules;
    };

  defaultRole = {
    nfsServer = "server04";
    slurmServer = "server04";
    slurmConfig = null;
  };
in lib.mapAttrs base (with self.nixosModules; {

  # CPU Server
  server01 = [
    {
      clusterRole = defaultRole // {
        network = {
          external = {
            interface = "eth0";
            address = "10.15.20.1";
          };
          internal = {
            interface = "eth1";
            address = "172.30.10.1";
          };
        };
        slurmConfig = {
          CPUs = 256;
          Sockets = 2;
          CoresPerSocket = 64;
          ThreadsPerCore = 2;
        };
      };
    }

    slurmClient
  ];
  # CPU Server
  server02 = [
    {
      clusterRole = defaultRole // {
        network = {
          external.interface = "eth0";
          internal = {
            interface = "eth1";
            address = "172.30.10.2";
          };
        };

        slurmConfig = {
          CPUs = 256;
          Sockets = 2;
          CoresPerSocket = 64;
          ThreadsPerCore = 2;
        };
      };
    }
    slurmClient
  ];
  # CUDA Server
  server03 = [
    {
      clusterRole = defaultRole // {
        network = {
          external.interface = "eth0";
          internal = {
            interface = "eth1";
            address = "172.30.10.3";
          };
        };

        slurmConfig = {
          CPUs = 16;
          Sockets = 1;
          CoresPerSocket = 16;
          ThreadsPerCore = 1;
        };
      };
    }
    slurmClient
  ];
  # Central Server
  server04 = [
    {
      clusterRole = defaultRole // {
        network = {
          external.interface = "eth0";
          internal = {
            interface = "eth1";
            address = "172.30.10.4";
          };
        };
      };
    }
    slurmServer
    kanidm
  ];
})
