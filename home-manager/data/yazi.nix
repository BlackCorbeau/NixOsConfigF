{ pkgs, lib, ... }: 
let yazi-plugins = pkgs.fetchFromGitHub {
		owner = "yazi-rs";
		repo = "plugins";
		rev = "c5785059611624e20a37ba573620f30acc28a26a";
		hash = "sha256-wlSBtabIsEUJhuHmXwgpSnwZp9WaVQFBg6s1XXjubrE=";
	};
	starship = pkgs.fetchFromGitHub {
		owner = "Rolv-Apneseth";
		repo = "starship.yazi";
		rev = "d1cd0a38aa6a2c2e86e62a466f43e415f781031e";
		sha256 = "sha256-XiEsykudwYmwSNDO41b5layP1DqVa89e6Emv9Qf0mz0=";
	};
in {
	programs.yazi = {
		enable = true;
		enableZshIntegration = true;
		shellWrapperName = "y";

		settings = {
			manager = {
				show_hidden = true;
			};
			preview = {
			    image_filter = "lanczos3";
                            image_quality = 90;
                            tab_size = 1;
                            max_width = 600;
                            max_height = 900;
                            cache_dir = "";
                            ueberzug_scale = 1;
                            ueberzug_offset = [
                                0
                                0
                                0
                                0
                            ];	
			};
		};

		plugins = {
			chmod = "${yazi-plugins}/chmod.yazi";
			full-border = "${yazi-plugins}/full-border.yazi";
			max-preview = "${yazi-plugins}/max-preview.yazi";
			starship = starship;
		};

		initLua = ''
			require("full-border"):setup()
			require("starship"):setup()
		'';

		keymap = {
			manager.prepend_keymap = [
				{
					on = "T";
					run = "plugin --sync max-preview";
					desc = "Maximize or restore the preview pane";
				}
				{
					on = ["c" "m"];
					run = "plugin chmod";
					desc = "Chmod on selected files";
				}
				{
					on = [ "<C-n>" ];
					run = ''shell '${lib.getExe pkgs.xdragon} -x -i -T "$@"' --confirm'';
				}
			];
		};
	};
}
