COMPOSE    := docker compose


.PHONY:  docker-up docker-down docker-reset  docker-ps 

docker-up:
	$(COMPOSE) up -d

docker-down:
	$(COMPOSE) down

# Wipe volumes and start fresh (re-runs migrations + bootstrap)
docker-reset:
	$(COMPOSE) down -v
	$(COMPOSE) up -d

docker-ps:
	$(COMPOSE) ps
