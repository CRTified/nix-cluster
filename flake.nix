{
  description = ''
    A nix configuration of a SLURM-based HPC cluster.
  '';

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    sops-nix.url = "github:Mic92/sops-nix";
    nixinate.url = "github:matthewcroughan/nixinate";
  };

  outputs = { self, nixpkgs, sops-nix, nixinate }:
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

      nixosModules = {
        common = import ./modules/common.nix;
        impureCompiler = import ./modules/impureCompiler.nix;
        internalNetwork = import ./modules/internalNetwork.nix;

        slurmCommon = import ./modules/slurmCommon.nix;
        munged = import ./modules/munged.nix;
        slurmClient = import ./modules/slurmClient.nix;
        slurmServer = import ./modules/slurmServer.nix;

        kanidm = import ./modules/kanidm.nix;
        nfs = import ./modules/nfs.nix;
      };

      nixosConfigurations = let
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
      });

      checks.x86_64-linux = {
        integration_check =
          (import nixpkgs { system = "x86_64-linux"; }).nixosTest {
            name = "Integration test";
            nodes = lib.mapAttrs (name: conf:
              let clusterRole = conf.config.clusterRole;
              in { pkgs, lib, ... }: {
                imports = conf._module.args.modules;

                users.users.root.password = "1234";

                virtualisation.interfaces = {
                  ${clusterRole.network.external.interface} = {
                    vlan = 1;
                    assignIP = true;
                  };
                  ${clusterRole.network.internal.interface} = {
                    vlan = 2;
                    assignIP = false;
                  };
                };

                clusterRole.slurmConfig = lib.mkForce {
                  CPUs = 1;
                  Sockets = 1;
                  CoresPerSocket = 1;
                  ThreadsPerCore = 1;
                };

                sops = {
                  defaultSopsFile = lib.mkForce ./secrets.test.yaml;
                  age = {
                    generateKey = false;
                    sshKeyPaths = lib.mkForce [ ];
                    keyFile = lib.mkForce (pkgs.writeText "agekey" ''
                      AGE-SECRET-KEY-1S8LWZAA3APEM59KTLTCDLNVQE0S0830XYFGW695S0MLZ0CUXZ3WSPRQ5Z9
                    '');
                  };
                };
              }) self.nixosConfigurations;
            testScript = ''
              start_all()

              # Wait for all nodes to boot and settle
              ${lib.concatMapStringsSep "\n"
              (node: ''${node}.wait_for_unit("multi-user.target")'')
              (lib.attrNames self.nixosConfigurations)}

              # Run collected tests
              ${lib.concatMapStringsSep "\n" (node:
                lib.concatStringsSep "\n" (lib.attrValues
                  (lib.filterAttrs (n: _: lib.hasPrefix "test-" n)
                    node._module.args)))
              (lib.attrValues self.nixosConfigurations)}
            '';
          };
      };
    };
}
