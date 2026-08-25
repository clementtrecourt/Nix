{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.tmux = {
    enable = true;

    # ============================================
    # Options de base natives
    # ============================================
    mouse = true;
    baseIndex = 1;
    escapeTime = 0; # Crucial pour Neovim (pas de délai ESC)
    historyLimit = 50000;
    keyMode = "vi";
    terminal = "tmux-256color";

    # ============================================
    # Configuration avancée & Raccourcis
    # ============================================
    extraConfig = ''
      # ---------------------------------------------------------
      # 1. PARAMÈTRES SUPPLÉMENTAIRES
      # ---------------------------------------------------------
      setw -g pane-base-index 1
      set-window-option -g pane-base-index 1
      set-option -g renumber-windows on
      set -g focus-events on
      set -ag terminal-overrides ",xterm-256color:RGB"

      # ---------------------------------------------------------
      # 2. GESTION DES FENÊTRES ET SPLITS (Sans préfixe)
      # ---------------------------------------------------------
      bind -n M-t new-window -c "#{pane_current_path}"
      bind -n M-w kill-pane
      bind -n M-/ split-window -h -c "#{pane_current_path}"
      bind -n M-- split-window -v -c "#{pane_current_path}"

      # ---------------------------------------------------------
      # 3. NAVIGATION ENTRE LES SPLITS (Alt + hjkl)
      # ---------------------------------------------------------
      bind -n M-h select-pane -L
      bind -n M-l select-pane -R
      bind -n M-k select-pane -U
      bind -n M-j select-pane -D

      # ---------------------------------------------------------
      # 4. REDIMENSIONNER LES SPLITS (Ctrl + Flèches)
      # ---------------------------------------------------------
      bind -n C-Left resize-pane -L 5
      bind -n C-Right resize-pane -R 5
      bind -n C-Up resize-pane -U 5
      bind -n C-Down resize-pane -D
      bind-key -n M-e resize-pane -Z

      # ---------------------------------------------------------
      # 5. ESTHÉTIQUE DE LA BARRE D'ÉTAT (Minimaliste & Cyan)
      # ---------------------------------------------------------
      set -g status-position bottom
      set -g status-style bg=default,fg=white
      set -g status-right ""

      set -g status-left "#[fg=cyan,bold] #S #[default]  "
      set -g status-left-length 20

      setw -g window-status-format "#[fg=gray] #I:#W "
      setw -g window-status-current-format "#[bg=cyan,fg=black,bold] #I:#W "

      # ---------------------------------------------------------
      # 6. NAVIGATION RAPIDE ONGLETS (Alt + 1..9)
      # ---------------------------------------------------------
      bind -n M-1 select-window -t 1
      bind -n M-2 select-window -t 2
      bind -n M-3 select-window -t 3
      bind -n M-4 select-window -t 4
      bind -n M-5 select-window -t 5
      bind -n M-6 select-window -t 6
      bind -n M-7 select-window -t 7
      bind -n M-8 select-window -t 8
      bind -n M-9 select-window -t 9

      # ---------------------------------------------------------
      # 7. COPY-MODE (Style Vi)
      # ---------------------------------------------------------
      bind-key -n M-v copy-mode
      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi V send-keys -X select-line
      bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel
    '';
  };
}
