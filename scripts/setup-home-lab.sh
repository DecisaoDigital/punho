#!/usr/bin/env bash
# Setup Home Lab Claude / Maquina Claude Linux
# Instala: Flutter stable + Android SDK + JDK 21 + gh + git
# Idempotente: pode correr varias vezes.
# Log em ~/setup-home-lab.log

set -u
exec > >(tee -a ~/setup-home-lab.log) 2>&1
echo "=== INICIO $(date -Iseconds) ==="

sudo -v || { echo "Sudo password necessaria."; exit 1; }

echo ""
echo "=== 0. Autorizar chave SSH do Cowork sandbox ==="
mkdir -p ~/.ssh && chmod 700 ~/.ssh
COWORK_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ69I71q7UVA6QQ6K0e0Z2iPnQLy68i93vD4Ztt+d22I cowork-sandbox"
if ! grep -qF "$COWORK_KEY" ~/.ssh/authorized_keys 2>/dev/null; then
  echo "$COWORK_KEY" >> ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys
  echo "Chave cowork-sandbox adicionada a ~/.ssh/authorized_keys"
else
  echo "Chave cowork-sandbox ja presente"
fi

echo ""
echo "=== 1. apt update + upgrade ==="
sudo apt-get update
sudo apt-get upgrade -y

echo ""
echo "=== 2. Ferramentas essenciais ==="
sudo apt-get install -y \
  git curl wget unzip xz-utils zip \
  openjdk-21-jdk-headless \
  build-essential \
  ca-certificates \
  libglu1-mesa

echo ""
echo "=== 3. OpenSSH server activo ==="
sudo systemctl enable --now ssh
sudo systemctl status ssh --no-pager | head -3

echo ""
echo "=== 4. GitHub CLI ==="
if ! command -v gh >/dev/null 2>&1; then
  sudo mkdir -p -m 755 /etc/apt/keyrings
  wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  sudo apt-get update
  sudo apt-get install -y gh
else
  echo "gh ja instalado: $(gh --version | head -1)"
fi

echo ""
echo "=== 5. Flutter SDK stable ==="
if [ ! -d "$HOME/flutter" ]; then
  cd "$HOME"
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
else
  echo "Flutter ja existe em ~/flutter"
  (cd "$HOME/flutter" && git pull --ff-only)
fi

echo ""
echo "=== 6. Android command-line tools ==="
if [ ! -d "$HOME/android-sdk/cmdline-tools/latest" ]; then
  mkdir -p "$HOME/android-sdk/cmdline-tools"
  cd "$HOME/android-sdk/cmdline-tools"
  wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O cmdline.zip
  unzip -q cmdline.zip
  mv cmdline-tools latest
  rm cmdline.zip
else
  echo "Android cmdline-tools ja existe"
fi

echo ""
echo "=== 7. PATH no ~/.bashrc ==="
grep -q 'flutter/bin' ~/.bashrc || cat >> ~/.bashrc <<'EOF'

# Home Lab Claude — Flutter + Android SDK
export ANDROID_HOME="$HOME/android-sdk"
export PATH="$HOME/flutter/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
EOF

# Carregar PATH para esta sessao
export ANDROID_HOME="$HOME/android-sdk"
export PATH="$HOME/flutter/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

echo ""
echo "=== 8. Aceitar licencas Android SDK + instalar plataformas ==="
yes | sdkmanager --licenses > /dev/null 2>&1 || true
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

echo ""
echo "=== 9. Verificacao final ==="
flutter --version
echo ""
java -version
echo ""
gh --version | head -1
echo ""
git --version

echo ""
echo "=== FIM $(date -Iseconds) ==="
echo ""
echo "TUDO OK. Fecha o SSH ('exit') e volta a ligar para apanhar o PATH."
echo "Log guardado em: ~/setup-home-lab.log"
