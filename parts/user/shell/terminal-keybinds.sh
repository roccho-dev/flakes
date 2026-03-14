#!/usr/bin/env bash
# Terminal keybindings for migrated commands

# Ctrl+F - Unified search (files, functions, keybindings)
bind -x '"\C-f": /home/nixos/bin/src/develop/terminal/unified-search'

# Legacy bindings (commented out - replaced by unified-search)
# bind -x '"\C-f\C-b": /home/nixos/bin/src/develop/terminal/search-keys'
# bind -x '"\C-f\C-f": /home/nixos/bin/src/develop/terminal/search-functions'
# bind -x '"\C-f": /home/nixos/bin/src/develop/terminal/cat-fzf'