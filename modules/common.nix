{ pkgs, lib, ... }: {
  services.prometheus.exporters = {
    # Exporter for hardware and OS metrics
    node = {
      enable = true;
      enabledCollectors = [ ];
      openFirewall = true;
    };
    # # Exporter for systemd metrics
    # TODO: Wait for Issue #34 to be closed
    # https://github.com/povilasv/systemd_exporter/issues/34
    # systemd = {
    #   enable = true;
    #   openFirewall = true;
    # };
  };
  security = {
    # Default directory structure - do we want to put something there?
    #pam.makeHomeDir.skelDirectory = "${pkgs.srcOnly { src = ./skel; }}";

    sudo.enable = false;
  };

  sops = {
    defaultSopsFile = ../secrets.prod.yaml;
    age = {
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = false;
    };
  };

  networking = {
    firewall = {
      enable = true;
      logRefusedConnections = false;
    };
  };

  environment = {
    systemPackages = with pkgs; [
      glib
      fplll
      m4ri
      boost
      gmp

      git

      gcc
      clang
      llvm
      openmpi
    ];
  };
}
