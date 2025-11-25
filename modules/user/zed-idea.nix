{pkgs, lib, ... }:

{
  programs.zed-editor = {
    enable = true;
    
    userSettings = {
      lsp.clangd = {
        binary.path = "${pkgs.clang-tools}/bin/clangd";
        settings = {
          arguments = [
            "--background-index"
            "--header-insertion=never"
            # Отключаем диагностику ошибок
            "--enable-config"  # Требуется для кастомных настроек
          ];
          # Конфиг clangd (переопределяет аргументы)
          config = {
            Diagnostics = {
              Enable = false;  # Полное отключение диагностики
            };
          };
        };
      };
    };
  };

  home.packages = with pkgs; [ clang-tools ];
}
