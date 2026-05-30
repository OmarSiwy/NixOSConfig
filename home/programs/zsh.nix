{ pkgs, ... }:
{
  services.ssh-agent.enable = true;
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" ];
      theme = "agnoster";
    };
    shellAliases = {
      ls = "lsd";
      l = "ls -l";
      la = "ls -a";
      lla = "ls -la";
      lt = "ls --tree";
      listen-to-ipad = "uxplay -p -n \"Omar's Computer\"";
    };
    initContent = ''
      fastfetch -c $HOME/.config/fastfetch/config-compact.jsonc
      source <(fzf --zsh)
      HISTFILE=~/.zsh_history
      HISTSIZE=10000
      SAVEHIST=10000
      setopt appendhistory
      export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
      if ! ssh-add -l &>/dev/null; then
        ssh-add ~/.ssh/id_rsa
      fi
    '';
  };
  home.packages = with pkgs; [
    lsd
    fzf
  ];
}
