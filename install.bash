#!/bin/bash

# Ubuntu Setup Script - Enhanced Version
set -e  # Exit on any error

echo "=== Ubuntu Setup Script Starting ==="

# Update system first
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Basic utilities first
echo "Installing basic utilities..."
sudo apt install -y git curl wget htop neofetch vlc build-essential software-properties-common apt-transport-https ca-certificates gnupg lsb-release

# Python and pip
echo "Installing Python..."
sudo apt install -y python3 python3-pip python3-venv

# Node.js (using NodeSource repository for latest version)
echo "Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs

# Go (latest version)
echo "Installing Go..."
GO_VERSION=$(curl -s https://api.github.com/repos/golang/go/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
wget https://go.dev/dl/${GO_VERSION}.linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf ${GO_VERSION}.linux-amd64.tar.gz

# VS Code
echo "Installing VS Code..."
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
sudo apt update
sudo apt install -y code

# Brave browser
echo "Installing Brave browser..."
sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main"|sudo tee /etc/apt/sources.list.d/brave-browser-release.list
sudo apt update
sudo apt install -y brave-browser

# Snap packages
echo "Installing snap packages..."
sudo snap install blender --classic
sudo snap install spotify
sudo snap install krita
sudo snap install btop

# Miniconda
echo "Installing Miniconda..."
if [ ! -d "$HOME/miniconda3" ]; then
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
    bash Miniconda3-latest-Linux-x86_64.sh -b -p $HOME/miniconda3
    rm -f Miniconda3-latest-Linux-x86_64.sh
fi

# Install Zsh (but don't configure yet)
echo "Installing Zsh..."
sudo apt install -y zsh zsh-autosuggestions zsh-syntax-highlighting

# Add paths to both bashrc and future zshrc
echo "Configuring environment paths..."
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
echo 'export PATH="$HOME/miniconda3/bin:$PATH"' >> ~/.bashrc

# Create initial zshrc with paths
cat >> ~/.zshrc << 'EOF'
export PATH=$PATH:/usr/local/go/bin
export PATH="$HOME/miniconda3/bin:$PATH"
EOF

echo "=== Basic installation complete ==="
echo ""
echo "IMPORTANT: To complete the setup, run the following commands manually:"
echo "1. Install Oh My Zsh: sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
echo "2. After Oh My Zsh is installed, run: bash ~/Desktop/UbuntuSetUp/configure_zsh.bash"
echo "3. Change default shell: chsh -s \$(which zsh)"
echo ""

# Clean up downloaded files
rm -f ${GO_VERSION}.linux-amd64.tar.gz packages.microsoft.gpg

echo "=== Setup script completed ==="