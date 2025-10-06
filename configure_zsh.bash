#!/bin/bash

# Zsh Configuration Script - Run this AFTER installing Oh My Zsh
set -e

echo "=== Configuring Zsh plugins ==="

# Check if Oh My Zsh is installed
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Error: Oh My Zsh not found. Please install it first:"
    echo "sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
    exit 1
fi

# Set ZSH_CUSTOM if not set
export ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

# Install Zsh plugins
echo "Installing zsh-autosuggestions..."
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions.git $ZSH_CUSTOM/plugins/zsh-autosuggestions
fi

echo "Installing zsh-syntax-highlighting..."
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
fi

echo "Installing fast-syntax-highlighting..."
if [ ! -d "$ZSH_CUSTOM/plugins/fast-syntax-highlighting" ]; then
    git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git $ZSH_CUSTOM/plugins/fast-syntax-highlighting
fi

echo "Installing zsh-autocomplete..."
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autocomplete" ]; then
    git clone --depth 1 -- https://github.com/marlonrichert/zsh-autocomplete.git $ZSH_CUSTOM/plugins/zsh-autocomplete
fi

# Update .zshrc with plugins
echo "Updating .zshrc with plugins..."
sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting zsh-autocomplete)/' ~/.zshrc

# Ensure paths are in .zshrc
echo "Adding environment paths to .zshrc..."
grep -q 'export PATH=$PATH:/usr/local/go/bin' ~/.zshrc || echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.zshrc
grep -q 'export PATH="$HOME/miniconda3/bin:$PATH"' ~/.zshrc || echo 'export PATH="$HOME/miniconda3/bin:$PATH"' >> ~/.zshrc

echo "=== Zsh configuration complete ==="
echo "Please restart your terminal or run: source ~/.zshrc"
