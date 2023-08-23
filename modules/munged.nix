{ lib, config, nodes, ... }: let
  clusterNodes = lib.mapAttrs (name: value: value.config.clusterRole) nodes;
in {

  _module.args.test-munge = let source = config.networking.hostName;
  in ''
    with subtest("munged credential grouping"):
      cred = ${source}.succeed("munge -s 'Hello from ${source}'")
      ${
        lib.concatMapStringsSep "\n  "
        (target: ''${target}.succeed(f"echo '{cred}' | unmunge")'')
        (lib.attrNames clusterNodes)
      }
  '';

  sops.secrets.munged = {
    reloadUnits = [ "munged.service" ];

    owner = config.systemd.services.munged.serviceConfig.User;
    group = config.systemd.services.munged.serviceConfig.Group;
    mode = "0400";
  };

  systemd.services.munged = {
    serviceConfig.SupplementaryGroups = [ config.users.groups.keys.name ];
  };

  services.munge = {
    enable = true;
    password = config.sops.secrets.munged.path;
  };
}
