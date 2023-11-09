just:
    echo "hi"

docker-build:
    docker build -t geng --build-arg PLATFORMS=all .