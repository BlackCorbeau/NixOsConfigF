{config, pkgs, pkgs-stable, pkgs-pinned, lib, inputs, name, fullname ? name, ... }: {
  imports = [
    inputs.home-manager.nixosModules.home-manager {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "rebuild";
        overwriteBackup = true;
        
        users.${name} = {
          imports = [
            inputs.sops-nix.homeManagerModules.sops
            inputs.stylix.homeModules.stylix
            ../modules/user.nix
            ./${name}/modules/git.nix
            ./${name}/modules/niri.nix
            ./${name}/modules/style.nix
            ./${name}/home.nix
          ];

          home = {
            username = name;
            homeDirectory = "/home/${name}";
            stateVersion = "23.11";
          };
        };
        extraSpecialArgs = {
          inherit inputs;
          inherit pkgs-stable;
          inherit pkgs-pinned;
          host = {
            name = config.networking.hostName;
          };
          username = name;
        };
      };
    }
  ];

  programs.zsh.enable = true;

  users = {
    defaultUserShell = pkgs.zsh;

    users."${name}" = {
      isNormalUser = true;
      description = fullname;
      extraGroups = [ "networkmanager" "wheel" "input" "libvirtd" ];
    };
  };

  services.greetd = let
    tuigreet = lib.getExe pkgs.tuigreet;
    session = pkgs.writeShellScript "niri-session-${name}" ''
      export PATH="/etc/profiles/per-user/${name}/bin:$PATH"
      hm_session_vars="/etc/profiles/per-user/${name}/etc/profile.d/hm-session-vars.sh"
      if [ -r "$hm_session_vars" ]; then
        . "$hm_session_vars"
      fi
      exec ${config.programs.niri.package}/bin/niri-session
    '';
  in {
    enable = true;
    settings = {
      initial_session = {
        command = "${session}";
        user = "${name}";
      };
      default_session = {
        command = "${tuigreet} --greeting 'Welcome to NixOS!' --asterisks --remember --remember-user-session --time -cmd ${session}";
        user = "greeter";
      };
    };
  };

  nix.settings.trusted-users = [ name ];
}
