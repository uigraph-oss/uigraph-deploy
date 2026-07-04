# uigraph-deploy

[![license](https://img.shields.io/badge/license-BUSL--1.1-blue)](LICENSE)

Docker Compose deployment for self-hosting [UiGraph](https://uigraph.app). Clone this repo, run one command, and the entire stack — API, GraphQL, UI, and bundled Postgres/Redis/MinIO — comes up with working defaults. No `.env` file required.

## What is UiGraph?

UiGraph is a platform for documenting how a system actually works — for engineering, product, and platform teams who need a shared, living picture of their architecture instead of diagrams that go stale in a wiki.

- **Maps** group frames around a feature, flow, or domain — the top-level unit of documentation.
- **Frames** are the screens, diagrams, or other visual artifacts inside a map.
- **Points** link a region of a frame to implementation details (an API, a service, a database table) or to another map/frame, so a UI element is traceable straight to the code and data behind it.
- **Database modeling** turns SQL and NoSQL schemas (including DynamoDB) into visual, explorable structures.
- **`uigraph-cli`** syncs service metadata, API specs, Mermaid diagrams, tests, and database schemas from a repository's `.uigraph.yaml` into UIGraph, so documentation updates ship as part of normal delivery instead of a separate chore.
- **MCP server** ([`uigraph-mcp`](https://github.com/uigraph-oss/uigraph-mcp)) exposes maps, frames, and points to AI coding assistants, so an agent can pull the same architectural context a human would.

Full product docs (guides, `uigraph-cli`, self-hosting reference) live at the [UiGraph documentation site](https://docs.uigraph.app).

## Quick start

```bash
git clone https://github.com/uigraph-oss/uigraph-deploy
cd uigraph-deploy

make docker-up      # docker compose up -d
```

Wait for the containers to report healthy (`make docker-ps`), then open **http://localhost:3000** and sign in with:

- **Email:** `admin@uigraph.app`
- **Password:** `admin`


### What's running

| Port | Service | Notes |
|---|---|---|
| `3000` | `uigraph-ui` | The web app — start here. |
| `8080` | `uigraph-api` | REST API. |
| `8090` | `uigraph-graphql` | GraphQL API. |
| `8081` | `uigraph-gateway` | Presigns storage uploads (maps to container port `8080`). |
| `5432` | `postgres` | Bundled database. |
| `9000` / `9001` | `minio` | Object storage API and web console. |

On first boot, `uigraph-api` connects to Postgres, applies all migrations, seeds a `default` org, and creates the bootstrap admin above.

> **These defaults are for local evaluation only.** `docker-compose.yml` ships placeholder secrets (`UIGRAPH_SECRET_KEY`, `STORAGE_SECRET_KEY`, and `devpassword` database/MinIO passwords) and serves the app over plain HTTP on `localhost`. Before exposing this to anyone else: change the admin password, replace every secret with real values (`openssl rand -hex 32`), and put the app behind TLS.

## Learn more / go to production

This README covers local evaluation. For everything else, see the self-hosting docs:

- [Quick Start](https://docs.uigraph.app/self-hosting/quick-start) — this same walkthrough, plus more detail
- [Environment Variables](https://docs.uigraph.app/self-hosting/environment-variables) — every setting `docker-compose.yml` defines, by service
- [Authentication & SSO](https://docs.uigraph.app/self-hosting/authentication) — password login, OAuth2/OIDC (Entra ID, Okta, GitHub, generic OIDC), sessions, role mapping
- [Operations](https://docs.uigraph.app/self-hosting/operations) — TLS, upgrades, backups

## License

This project is licensed under the [Business Source License 1.1](LICENSE) (BUSL-1.1).

- **Source available today** — you can read, modify, and redistribute the code under the terms of the license.
- **Non-production use** — free for development, testing, evaluation, and internal proof-of-concept.
- **Production use** — requires a commercial license from UiGraph. Production use means any use that supports the ongoing operation of your business or organization.
- **Future open source** — each version automatically converts to [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0) four years after it is first published under BUSL.

BUSL is not an OSI-approved open source license during the initial term. For commercial licensing questions, open an issue or contact the maintainers.

## Related projects

- [uigraph-api](https://github.com/uigraph-oss/uigraph-api) — backend API
- [uigraph-ui](https://github.com/uigraph-oss/uigraph-ui) — web application
- [uigraph-graphql](https://github.com/uigraph-oss/uigraph-graphql) — GraphQL BFF
- [uigraph-gateway](https://github.com/uigraph-oss/uigraph-gateway) — CLI sync API
- [uigraph-mcp](https://github.com/uigraph-oss/uigraph-mcp) — MCP server for AI assistants
- [uigraph-sdk](https://github.com/uigraph-oss/uigraph-sdk) — TypeScript SDK
</content>
