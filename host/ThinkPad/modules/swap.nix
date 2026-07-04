{
  zramSwap = {
  enable = true;
  algorithm = "lz4";
  memoryPercent = 30;
  };

  swapDevices = [
    { device = "/swapfile"; size = 4096; }
  ];
}
