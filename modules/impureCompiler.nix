{ pkgs, lib, ... }: {
  environment = {
    pathsToLink = [ "/include" ];
    variables = {
      CPATH = "/run/current-system/sw/include";
      LIBRARY_PATH = "/run/current-system/sw/lib";
    };
  };
}
