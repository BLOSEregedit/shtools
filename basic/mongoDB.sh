
echo
echo "********    安装 mongoDB  ─=≡Σ((( つ•̀ω•́)つ     ********"
echo
echo "01 创建文件夹  -->   /root/mongo/ "
# Create mongoDB
mkdir -p /root/mongo /root/mongo/data /root/mongo/log /root/mongo/config
echo
echo "02 写入配置文件  -->  /root/docker-compose.yml "
echo
# Write file content
cat <<EOF > /root/docker-compose.yml
---
version: "3.9"
services:
  mongodb:
    container_name: mongo
    image: mongo:latest
    restart: always
    ports:
      - 8080:27017
    volumes:
      - ./mongo/data:/data/db
      - ./mongo/log:/var/log/mongodb
    environment:
      MONGO_INITDB_ROOT_USERNAME: root
      MONGO_INITDB_ROOT_PASSWORD: 6Wr^Zivyc%eKZ!bxi7QkP
EOF

# start mongoDB
echo
echo "********    拉取镜像并启动    ********"
echo
docker compose up -d
echo
echo "********    ( ´∀｀)つt[ okk～ ]    ********"
echo
echo "账号：root"
echo "密码：6Wr^Zivyc%eKZ!bxi7QkP"
echo
echo
echo "container_name：mongo"
echo "端口：8080"
echo

