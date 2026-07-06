{ config, ... }: {
  services.fprintd.enable = true;

  security.pam.services = {
    sudo.fprintAuth = true;
    login.fprintAuth = false;
  };

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "net.reactivated.fprint.device.enroll" &&
          subject.isInGroup("fprint")) {
        return polkit.Result.YES;
      }
    });
  '';

  users.users.kirill.extraGroups = [ "fprint" ];
}
