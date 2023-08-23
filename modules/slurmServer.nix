{ pkgs, lib, config, nodes, ... }: let
  clusterNodes = lib.mapAttrs (name: value: value.config.clusterRole) nodes;
in {
  _module.args.test-slurmServer = let
    source = config.networking.hostName;
    computeNodes = lib.filterAttrs (_: v: v.slurmConfig != null) clusterNodes;
    computeNodesNum = lib.length (lib.attrNames computeNodes);
  in ''
    with subtest("Slurm Test from ${source}"):
      ${source}.wait_for_unit("slurmdbd.service")
      ${source}.wait_for_unit("slurmctld.service")
      ${source}.succeed("srun --immediate=15 -N${toString computeNodesNum} 'hostname'")
  '';

  systemd.services = {
    slurmdbd = {
      # For connection to localhost, mysql_real_connect
      # checks whether it can connect over a unix_socket.
      # This allows authentication by local user and removes
      # the need for a secret.
      #
      # To make this work, we need to set the environment variable
      # MYSQL_UNIX_PORT and let slurmdbd run as slurm instead of root
      # (done by `SlurmUser=slurm`).
      environment.MYSQL_UNIX_PORT = "/var/run/mysqld/mysqld.sock";
    };

    slurmctld = {
      preStart = ''
        # Delay starting so that `slurmdbd.service` can settle.
        sleep 1
      '';
      after = [ "slurmdbd.service" ];
      requires = [ "slurmdbd.service" ];
    };
  };

  networking.firewall.interfaces."${config.clusterRole.network.internal.interface}".allowedTCPPorts =
    [
      6817 # Default port for slurmctld
      #6819 # Default port for slurmdbd. Not needed, at it runs on localhost
    ];

  services = {
    slurm = {
      server.enable = true;

      dbdserver = {
        enable = true;
        extraConfig = ''
          PidFile=/run/slurmdbd.pid
          StorageHost=localhost
        '';
      };
    };

    mysql = {
      enable = true;
      package = pkgs.mariadb;

      ensureDatabases = [ "slurm_acct_db" ];
      ensureUsers = [{
        ensurePermissions = { "slurm_acct_db.*" = "ALL PRIVILEGES"; };
        name = "slurm";
      }];

      settings.mysqld = {
        bind-address = "localhost";

        # recommendations from: https://slurm.schedmd.com/accounting.html#mysql-configuration
        innodb_buffer_pool_size = "1024M";
        innodb_log_file_size = "64M";
        innodb_lock_wait_timeout = 900;
      };
    };
  };
}
