#!/bin/bash

# install.sh
echo "Installing required tools for Subsnap..."

# Update package lists
sudo apt update

# Install Go (required for some tools)
sudo apt install -y golang

# Install required tools
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/tomnomnom/assetfinder@latest
sudo apt install -y sublist3r
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/LukaSikic/subzy@latest
sudo apt install -y python3-pip
pip3 install eyewitness

# Add Go binaries to PATH
echo 'export PATH=$PATH:~/go/bin' >> ~/.bashrc
source ~/.bashrc

echo "Installation complete. Please restart your terminal or source your .bashrc file."
