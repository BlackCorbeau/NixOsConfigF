{
  sops = {
    age.keyFile = "/root/age.key";

    secrets = {
      wallhaven = {
        format = "binary";
        sopsFile = ./wallhaven.pem;
        owner = "kirill";
        mode = "0400";
      };
    };
  };
}
