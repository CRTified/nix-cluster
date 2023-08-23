{ config, ... }: {
  networking.firewall.interfaces."${config.clusterRole.network.internal.interface}".allowedTCPPorts =
    [ 6818 ];

  services.slurm = { client = { enable = true; }; };
}
