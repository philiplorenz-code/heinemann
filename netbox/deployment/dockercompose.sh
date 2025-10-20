git clone https://github.com/netbox-community/netbox-docker.git
cd netbox-docker
docker compose -f docker-compose.yml -f docker-compose.test.override.yml up -d

docker compose exec netbox /opt/netbox/netbox/manage.py createsuperuser