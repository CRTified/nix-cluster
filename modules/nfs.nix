{ config, lib, nodes, ... }:
let
  clusterNodes = lib.mapAttrs (name: value: value.config.clusterRole) nodes;
  nfsServer = config.clusterRole.nfsServer;
  isNfsServer = nfsServer == config.networking.hostName;

  fsDefinition = if (!isNfsServer) then {
    "/home" = {
      device = "${nfsServer}-link:/home";
      fsType = "nfs4";
      options = [
        "rw"
        "_netdev"
        "vers=4.1"
        "x-systemd.mount-timeout=5min" # Wait a *long* time until NFS fails
        "x-systemd.automount"
      ];
    };
  } else {
    "/export/home" = {
      device = "/home";
      options = [ "bind" ];
    };
  };
in {
  _module.args.test-nfs = let source = config.networking.hostName;
  in ''
    with subtest("NFS Access to ${nfsServer} from ${source}"):
      ${source}.execute("touch /home/${source}")
      ${nfsServer}.wait_for_file("/home/${source}")

      ${nfsServer}.execute("touch /home/${source}-2")
      ${source}.wait_for_file("/home/${source}-2")
  '';

  virtualisation.fileSystems = fsDefinition;

  fileSystems = fsDefinition;

  systemd.tmpfiles.rules =
    lib.optionals (isNfsServer) [ "d /export 0555 root root -" ];

  services.nfs.server = {
    enable = isNfsServer;
    exports = ''
      /export       ${config.clusterRole.network.internal.address}/24(ro,root_squash,fsid=0)
      /export/home  ${config.clusterRole.network.internal.address}/24(rw,no_root_squash,insecure)
    '';
  };

  networking.firewall.interfaces."${config.clusterRole.network.internal.interface}".allowedTCPPorts =
    [
      111 # rpcbind
      2049 # NFSv4
    ];
}
