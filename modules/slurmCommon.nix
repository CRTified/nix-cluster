{ lib, config, nodes, ... }:
let
  clusterNodes = lib.mapAttrs (name: value: value.config.clusterRole) nodes;
  computeNodes = lib.filterAttrs (_: v: v.slurmConfig != null) clusterNodes;
in {
  networking.firewall.interfaces."${config.clusterRole.network.internal.interface}" = {
    allowedTCPPortRanges = [{
      from = 60001;
      to = 63000;
    }];
  };

  services.slurm = {
    clusterName = "nix-cluster";
    controlMachine = config.clusterRole.slurmServer;
    controlAddr = "${config.clusterRole.slurmServer}-link";

    nodeName = lib.mapAttrsToList (n: role:
      "${n} NodeAddr=${n}-link STATE=UNKNOWN ${
        lib.concatStringsSep " "
          (lib.mapAttrsToList (k: v: "${k}=${toString v}") role.slurmConfig)
      }") computeNodes;

    partitionName = [
      "debug Nodes=${
        lib.concatStringsSep "," (lib.attrNames computeNodes)
      } Default=YES MaxTime=INFINITE State=UP"
    ];

    extraConfig = ''
      AccountingStorageHost=${config.clusterRole.slurmServer}-link
      AccountingStorageType=accounting_storage/slurmdbd

      TCPTimeout=5

      SrunPortRange=60001-63000
      ResumeTimeout=600

    '';
  };
}
