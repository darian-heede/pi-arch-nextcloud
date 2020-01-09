#!/bin/bash
sudo docker-compose pull
sudo docker-compose up --build --detach
#sudo docker down -v
#sudo docker rmi $(sudo docker images -q) --force
#sudo docker rm $(sudo docker ps -q) --force
