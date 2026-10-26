{ lib, pkgs, ... }: let
  pythonValidityPatch = pkgs.writeText "python-validity-python-3.14.patch" ''
    diff --git a/validitysensor/flash.py b/validitysensor/flash.py
    index d37f15a..be3d4a1 100644
    --- a/validitysensor/flash.py
    +++ b/validitysensor/flash.py
    @@ -34,6 +34,10 @@ def get_flash_info():
         rsp = tls.cmd(unhex('3e'))
         assert_status(rsp)
         rsp = rsp[2:]
    +    if len(rsp) < 0xe:
    +        # An uninitialised 06cb:009a returns only the success status word.
    +        # Let init_flash() format it instead of failing in struct.unpack().
    +        return FlashInfo(None, 0, 0, 0, 0, [])
         hdr = rsp[:0xe]
         rsp = rsp[0xe:]
         jid0, jid1, blocks, unknown0, blocksize, unknown1, pcnt = unpack('<HHHHHHH', hdr)
    diff --git a/validitysensor/init.py b/validitysensor/init.py
    index 18890c5..710668c 100644
    --- a/validitysensor/init.py
    +++ b/validitysensor/init.py
    @@ -25,8 +25,8 @@ def close():

     def open_common():
         init_data_dir()
    -    init_flash()
         usb.send_init()
    +    init_flash()
         tls.parse_tls_flash(read_tls_flash())
         tls.open()
         upload_fwext()
    diff --git a/validitysensor/usb.py b/validitysensor/usb.py
    index 9db2b07..353b2c7 100644
    --- a/validitysensor/usb.py
    +++ b/validitysensor/usb.py
    @@ -1,6 +1,7 @@
     import errno
     import logging
    +import time
     import typing
     from binascii import hexlify, unhexlify
     from enum import Enum
     from struct import unpack
    @@ -68,22 +69,32 @@ class Usb:
         def close(self):
             if self.dev is not None:
                 try:
                     self.dev.reset()
                     self.dev = None
                 except:
                     pass
    ${" "}
         def usb_dev(self):
             return self.dev
    ${" "}
    +    def cmd_retry_busy(self, command: bytes):
    +        # Metallica sensors can report 0x0104 for a few seconds after wake-up.
    +        for _ in range(20):
    +            rsp = self.cmd(command)
    +            status, = unpack('<H', rsp[:2])
    +            if status != 0x0104:
    +                return rsp
    +            time.sleep(0.5)
    +        return rsp
    +
         def send_init(self):
             # self.dev.set_configuration()
    ${" "}
             # TODO analyse responses, detect hardware type
    -        assert_status(self.cmd(unhexlify('01')))  # RomInfo.get()
    +        assert_status(self.cmd_retry_busy(unhexlify('01')))  # RomInfo.get()
             assert_status(self.cmd(unhexlify('19')))
    ${" "}
             # 43 -- get partition header(?) (02 -- fwext partition)
             # c28c745a in response is a FwextBuildtime = 0x5A748CC2
    -        rsp = self.cmd(unhexlify('4302'))  # get_fw_info()
    +        rsp = self.cmd_retry_busy(unhexlify('4302'))  # get_fw_info()
    ${" "}
  '';

  python-validity = pkgs.python3Packages.buildPythonApplication rec {
    pname = "python-validity";
    version = "0.15-unstable-2020-12-14";
    pyproject = true;

    src = pkgs.fetchFromGitHub {
      owner = "uunicorn";
      repo = "python-validity";
      rev = "a6bbc21dce7b8b3c3cd92378a0b2579a2fb45920";
      hash = "sha256-RflX7e6nd11pSg8mh3mjZiVGNUSdox/SKXHR4W+PhMs=";
    };

    postPatch = ''
      ${lib.getExe pkgs.gitMinimal} apply ${pythonValidityPatch}
    '';

    build-system = [ pkgs.python3Packages.setuptools ];

    dependencies = with pkgs.python3Packages; [
      cryptography
      dbus-python
      pygobject3
      pyusb
      pyyaml
    ];

    nativeBuildInputs = [ pkgs.makeWrapper ];

    postInstall = ''
      install -Dm755 dbus_service/dbus-service \
        "$out/lib/python-validity/dbus-service"
      install -Dm644 dbus_service/io.github.uunicorn.Fprint.conf \
        "$out/share/dbus-1/system.d/io.github.uunicorn.Fprint.conf"

      install -Dm755 dbus_service/dbus-service \
        "$out/bin/python-validity-service"
      install -Dm755 scripts/factory-reset.py \
        "$out/bin/validity-factory-reset"

      install -d "$out/share/python-validity/playground"
      install -m755 \
        scripts/dbus-cmd.py \
        scripts/lsdbus.py \
        scripts/factory-reset.py \
        scripts/prototype.py \
        "$out/share/python-validity/playground/"
    '';

    postFixup = ''
      wrapProgram "$out/bin/validity-sensors-firmware" \
        --prefix PATH : ${lib.makeBinPath [
          pkgs.findutils
          pkgs.innoextract
        ]}
    '';

    # Upstream does not have an automated test suite.
    doCheck = false;

    meta = {
      description = "Userspace driver for Validity and Synaptics fingerprint sensors";
      homepage = "https://github.com/uunicorn/python-validity";
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
    };
  };

  fprintd-clients = pkgs.runCommand "fprintd-clients" { } ''
    mkdir -p "$out/bin"
    for client in fprintd-delete fprintd-enroll fprintd-list fprintd-verify; do
      ln -s "${pkgs.fprintd}/bin/$client" "$out/bin/$client"
    done
  '';

  systemctl = lib.getExe' pkgs.systemd "systemctl";
  busctl = lib.getExe' pkgs.systemd "busctl";
  timeout = lib.getExe' pkgs.coreutils "timeout";
  sleep = lib.getExe' pkgs.coreutils "sleep";
  fprintdList = lib.getExe' pkgs.fprintd "fprintd-list";

  # python-validity initializes the sensor before it registers with
  # open-fprintd, so a successful ListEnrolledFingers call means the sensor is
  # usable.  This is used as ExecStartPost and by greetd ordering.
  waitForFprint = pkgs.writeShellScript "wait-for-fprint" ''
    for ((i = 0; i < 80; i++)); do
      if ${timeout} 1 ${fprintdList} root >/dev/null 2>&1; then
        exit 0
      fi
      ${sleep} 0.5
    done

    echo "wait-for-fprint: fingerprint backend did not become ready" >&2
    exit 0
  '';

  # The xHCI controller is reset during resume, which invalidates
  # python-validity's USB handle.  Restart it from a systemd-sleep hook: the
  # hook runs before logind emits PrepareForSleep(false), so hyprlock's
  # built-in fingerprint auth sees a working sensor as soon as it resumes.
  fprintResumeHook = pkgs.writeShellScript "fprint-resume" ''
    if [ "$1" != "post" ]; then
      exit 0
    fi

    # Stop the old instance first so its stale D-Bus target cannot be selected
    # by the readiness checks below.  Start without blocking because
    # python-validity's ExecStartPost waits for fprintd, but open-fprintd is
    # still suspended until Resume is called below.
    ${timeout} 10 ${systemctl} stop python3-validity.service || true
    ${systemctl} start --no-block python3-validity.service || true

    # Clear open-fprintd's suspended flag.  This also unblocks the new
    # python-validity instance's ExecStartPost.
    ${timeout} 10 ${busctl} call net.reactivated.Fprint /net/reactivated/Fprint/Manager \
      net.reactivated.Fprint.Manager Resume || true

    # Wait for the new backend to register.
    for ((i = 0; i < 30; i++)); do
      if ${timeout} 0.5 ${fprintdList} root >/dev/null 2>&1; then
        break
      fi
      ${sleep} 0.1
    done

    # The target now exists, so Resume reinitializes the sensor.  Wait for it
    # to become responsive before logind starts hyprlock's fingerprint auth.
    ${timeout} 10 ${busctl} call net.reactivated.Fprint /net/reactivated/Fprint/Manager \
      net.reactivated.Fprint.Manager Resume || true

    for ((i = 0; i < 30; i++)); do
      if ${timeout} 0.5 ${fprintdList} root >/dev/null 2>&1; then
        exit 0
      fi
      ${sleep} 0.1
    done

    echo "fprint-resume: fingerprint backend did not become ready" >&2
  '';

  sleepTargets = [
    "suspend.target"
    "hibernate.target"
    "hybrid-sleep.target"
    "suspend-then-hibernate.target"
  ];
in {
  services = {
    # The 06cb:009a sensor is driven by python-validity through open-fprintd;
    # stock fprintd/libfprint cannot handle it.
    fprintd.enable = false;

    dbus.packages = [
      pkgs.open-fprintd
      python-validity
    ];
  };

  security.pam.services = {
    greetd.fprintAuth = true;
    polkit-1.fprintAuth = true;
    sudo.fprintAuth = true;
    login.fprintAuth = true;

    # hyprlock still needs a PAM service for password authentication, but it
    # must not run pam_fprintd: its own D-Bus fingerprint implementation is
    # used instead.  Two implementations would fight over the device, and the
    # PAM one breaks when the sensor is reset across suspend.
    hyprlock = {};
  };

  environment.etc."systemd/system-sleep/50-fprint-resume".source = fprintResumeHook;

  systemd.services = {
    open-fprintd = {
      description = "Open FPrint daemon";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "dbus";
        BusName = "net.reactivated.Fprint";
        ExecStart = "${pkgs.open-fprintd}/lib/open-fprintd/open-fprintd";
        Restart = "on-failure";
      };
    };

    python3-validity = {
      description = "python-validity fingerprint sensor backend";
      wantedBy = [ "multi-user.target" ];
      after = [ "open-fprintd.service" ];
      wants = [ "open-fprintd.service" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${python-validity}/bin/python-validity-service";
        ExecStartPost = "-${waitForFprint}";
        Restart = "always";
        RestartSec = 2;
        RuntimeDirectory = "python-validity";
        RuntimeDirectoryMode = "0700";
        RuntimeDirectoryPreserve = "yes";
      };
    };

    open-fprintd-suspend = {
      description = "Suspend open-fprintd backends";
      wantedBy = sleepTargets;
      before = sleepTargets;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.open-fprintd}/lib/open-fprintd/suspend.py";
      };
    };
  };

  # The sleep hook above resumes open-fprintd before logind wakes the
  # graphical session.  The stock open-fprintd-resume unit runs later and
  # resets the sensor while hyprlock is already verifying, so it must not be
  # enabled.  Order greetd (and therefore Hyprland/hyprlock) after the
  # fingerprint backend so the first lock screen can use the sensor.
  systemd.services.greetd = {
    after = [ "python3-validity.service" ];
    wants = [ "python3-validity.service" ];
  };

  environment.systemPackages = [
    fprintd-clients
    python-validity
  ];
}
