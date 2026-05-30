{ username, ... }:

{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = username;
        email = "ok.elsawy@gmail.com";
      };
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      url."git@github.com:" = {
        insteadOf = "https://github.com/";
      };
    };
  };
}
