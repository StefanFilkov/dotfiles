# Remove the default login greeting
set -U fish_greeting

# Enable Starship prompt
starship init fish | source

# Aliases (Optional - Add your own!)
alias l="ls -la"
alias k="kubectl"