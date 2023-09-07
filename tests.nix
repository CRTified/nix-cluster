{ self, nixpkgs, system }:
let lib = nixpkgs.lib;
in {
  integration_check = (import nixpkgs { system = "x86_64-linux"; }).nixosTest {
    name = "Integration test";
    nodes = lib.mapAttrs (name: conf:
      let clusterRole = conf.config.clusterRole;
      in { pkgs, lib, ... }: {
        imports = conf._module.args.modules;

        users.users.root.password = "1234";

        virtualisation.interfaces = {
          ${clusterRole.network.external.interface} = {
            vlan = 1;
            # We don't need to test the external interface here
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

            # Provide sops-nix config with a throwaway key
            # This is only used for the testing set of secrets
            # I know that this can be considered "playing with fire"
            #  __________________
            # < Here be dragons! >
            #  ------------------
            #       \                    / \  //\
            #        \    |\___/|      /   \//  \\
            #             /0  0  \__  /    //  | \ \
            #            /     /  \/_/    //   |  \  \
            #            @_^_@'/   \/_   //    |   \   \
            #            //_^_/     \/_ //     |    \    \
            #         ( //) |        \///      |     \     \
            #       ( / /) _|_ /   )  //       |      \     _\
            #     ( // /) '/,_ _ _/  ( ; -.    |    _ _\.-~        .-~~~^-.
            #   (( / / )) ,-{        _      `-.|.-~-.           .~         `.
            #  (( // / ))  '/\      /                 ~-. _ .-~      .-~^-.  \
            #  (( /// ))      `.   {            }                   /      \  \
            #   (( / ))     .----~-.\        \-'                 .~         \  `. \^-.
            #              ///.----..>        \             _ -~             `.  ^-`  ^-_
            #                ///-._ _ _ _ _ _ _}^ - - - - ~                     ~-- ,.-~
            #                                                                   /.-~
            #
            keyFile = lib.mkForce (pkgs.writeText "agekey" ''
              AGE-SECRET-KEY-1S8LWZAA3APEM59KTLTCDLNVQE0S0830XYFGW695S0MLZ0CUXZ3WSPRQ5Z9
            '');
            #
            ############################################################################
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
          (lib.filterAttrs (n: _: lib.hasPrefix "test-" n) node._module.args)))
      (lib.attrValues self.nixosConfigurations)}
    '';
  };
}
