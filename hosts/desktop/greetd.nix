{ pkgs, username, ... }:

{
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        user = username;
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd river";
      };
    };
  };
}
