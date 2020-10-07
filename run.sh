#!/bin/bash
sudo docker-compose pull
sudo docker-compose up --build --detach
#sudo docker down -v
#sudo docker rmi $(sudo docker images -q) --force
#sudo docker rm $(sudo docker ps -q) --force

# Update process - step by step
#sudo docker-compose down
#sudo docker stop $(sudo docker ps -q)
#sudo docker rm $(sudo docker ps -aq)
#sudo docker rmi $(sudo docker images -q)
#sudo docker-compose pull
#sudo docker-compose up --build --detach

# Update process - short
#sudo docker-compose up --force-recreate --build --detach
#sudo docker image prune -f


