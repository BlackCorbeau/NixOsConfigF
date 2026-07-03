{
  zramSwap = {
  enable = true;
  algorithm = "lz4";
  memoryPercent = 50;
  };

  swapDevices = [
    { device = "/swapfile"; size = 4096; }
  ];
}
