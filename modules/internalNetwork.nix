{ config, lib, nodes, ... }:
let
  internalName = name: "${name}-link";
  clusterNodes = lib.mapAttrs (name: value: value.config.clusterRole) nodes;
in {
  _module.args.test-internalNetwork = let source = config.networking.hostName;
  in ''
    with subtest("Internal Network Reachability from ${source}"):
      ${
        lib.concatMapStringsSep "\n  "
        (target: ''${source}.succeed("ping -c1 ${internalName target}")'')
        (lib.attrNames clusterNodes)
      }
  '';

  networking = {
    interfaces = {
      "${config.clusterRole.network.internal.interface}" = {
        useDHCP = false;
        ipv4.addresses = [{
          inherit (config.clusterRole.network.internal) address;
          prefixLength = 24;
        }];
      };
    };

    hosts = lib.mapAttrs' (name: value:
      lib.nameValuePair (value.network.internal.address)
      [ (internalName name) ]) clusterNodes;
  };
}
