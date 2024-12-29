#!/bin/bash


docker run -d \
  --name lucky \
  --volume 容器外持久化路径:/goodluck \
  --network host \
  --restart always \
  gdy666/lucky