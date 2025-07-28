# .ide/Dockerfile
FROM python:3.12.11-bookworm

# 以及按需安装其他软件
# RUN apt-get update && apt-get install -y git

# 安装 code-server 和 vscode 常用插件
RUN curl -fsSL https://code-server.dev/install.sh | sh \
  && code-server --install-extension redhat.vscode-yaml \
  && code-server --install-extension dbaeumer.vscode-eslint \
  && code-server --install-extension eamodio.gitlens \
  && code-server --install-extension tencent-cloud.coding-copilot \
  && code-server --install-extension ms-python.python \
  && echo done

# 安装 ssh 服务(用于支持 VSCode 客户端通过 Remote-SSH 访问开发环境);
# libxml2-utils 为 Google WebP 工具包，可用于命令行 webp 处理(cwebp)
RUN apt update && \
    apt install -y \
    git git-lfs \
    webp \
    wget \
    unzip \
    openssh-server \
    vim \
    zsh \
    zip \
    libxml2-utils && \
    chsh -s /bin/zsh && \
    yes | zsh -c "$(curl -fsSL 'https://cnb.cool/Mintimate/tool-forge/oh-my-zsh/-/git/raw/main/AutoInstallZshWithPlugin.sh')"

# 指定字符集支持命令行输入中文（根据需要选择字符集）
ENV LANG C.UTF-8
ENV LANGUAGE C.UTF-8