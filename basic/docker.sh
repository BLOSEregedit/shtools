
echo
echo "********    安装 docker  ─=≡Σ((( つ•̀ω•́)つ     ********"
echo
echo "01 初始化 "
echo
# 标记 openssl 不更新，否则会让选择配置文件所在地
sudo apt-mark hold libcurl4-openssl-dev openssh-sftp-server openssh-server


echo
echo "02 添加 GPG key "
echo
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo
echo "03 添加资源 "
echo
# Add the repository to Apt sources:
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null



echo
echo "04 安装 latest 版本 "
echo
sudo apt-get update


sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin


echo
echo
echo "********     安装完成  ( ´∀｀)つt[ ]    ********"
echo
docker --version
echo