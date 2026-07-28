# uigraph-deploy

[![license](https://img.shields.io/badge/license-BUSL--1.1-blue)](LICENSE)

Docker Compose deployment for self-hosting [UiGraph](https://uigraph.app) — API, GraphQL, UI, and bundled Postgres/Redis/MinIO, up with one command and no `.env` file.

## What is UiGraph?

A living map of your system — every service's API contracts, docs, diagrams, and owning team, synced into one browsable graph. **Maps** pin product screenshots to that graph so a UI element traces straight to the code and data behind it; database modeling turns SQL/NoSQL schemas into explorable structures; the [MCP server](https://github.com/uigraph-oss/uigraph-mcp) exposes the same context to AI coding assistants.

Full product docs (guides, `uigraph-cli`, self-hosting reference) live at [docs.uigraph.app](https://docs.uigraph.app).

## Quick start

```bash
git clone https://github.com/uigraph-oss/uigraph-deploy
cd uigraph-deploy
make docker-up
```

One command. Brings up the entire stack — idempotent, safe to re-run. Wait for containers to report healthy (`make docker-ps`), then open **http://localhost:3000** (`admin@uigraph.app` / `admin`).

## What's running

| Port | Service | What it is |
|---|---|---|
| `3000` | `uigraph-ui` | The web app — start here |
| `8080` | `uigraph-api` | REST API |
| `8090` | `uigraph-graphql` | GraphQL API |
| `8081` | `uigraph-gateway` | Storage uploads + AI chat |
| `8082` | `uigraph-mcp` | MCP server for AI assistants |
| `5432` | `postgres` | Bundled database |
| `9000` / `9001` | `minio` | Object storage API + console |

> **Local evaluation only.** Ships placeholder secrets and plain HTTP. Before exposing this to anyone else: change the admin password, replace every secret (`openssl rand -hex 32`), and put it behind TLS — see [Operations](https://docs.uigraph.app/self-hosting/operations).

<details>
<summary><h2>Optional: enable AI chat</h2></summary>

Off by default — needs an LLM key:

```bash
export AI_PROVIDER_API_KEY=sk-...
make docker-up
```

Defaults to OpenAI's API via an OpenAI-compatible client. Switch provider with `AI_PROVIDER_NPM` / `AI_PROVIDER_MODEL`:

```bash
export AI_PROVIDER_API_KEY=sk-ant-...
export AI_PROVIDER_NPM=@ai-sdk/anthropic
export AI_PROVIDER_MODEL=claude-sonnet-4-5
```

Other packages: `@ai-sdk/openai`, `@ai-sdk/anthropic`, `@ai-sdk/google`,
`@ai-sdk/amazon-bedrock`, `@ai-sdk/mistral`, `@ai-sdk/openai-compatible`. Full
`AI_PROVIDER_*` reference: [Environment Variables](https://docs.uigraph.app/self-hosting/environment-variables).

</details>

<details>
<summary><h2>Optional: connect MCP</h2></summary>

MCP server runs at **http://localhost:8082**.

```bash
npm i -g @uigraph/mcp
export UIGRAPH_MCP_SERVER_URL="http://localhost:8082"

uigraph-mcp auth login
uigraph-mcp auth default-org "Main Org"
```

</details>

## Troubleshooting

- **Docker daemon not running** — start Docker Desktop, re-run.
- **Something won't come up** — `docker compose logs <service>`.
- **Start over** — `make docker-reset` wipes all data.
- **Ports in use** — needs 3000, 5432, 8080, 8081, 8082, 8090, 9000-9001 free.

## Learn more / go to production

- [Quick Start](https://docs.uigraph.app/self-hosting/quick-start) — this same walkthrough, plus more detail
- [Environment Variables](https://docs.uigraph.app/self-hosting/environment-variables) — every setting, by service
- [Authentication & SSO](https://docs.uigraph.app/self-hosting/authentication) — password login, OAuth2/OIDC (Entra ID, Okta, GitHub, generic OIDC), sessions, role mapping
- [Operations](https://docs.uigraph.app/self-hosting/operations) — TLS, upgrades, backups

Deploying to production on AWS? See [`k8s/README.md`](k8s/README.md) for a Helm chart + Terraform path onto an existing EKS cluster, backed by RDS/ElastiCache/S3 instead of the bundled Postgres/Redis/MinIO above.

## License

This project is licensed under the [Business Source License 1.1](LICENSE) (BUSL-1.1).

- **Source available today** — read, modify, and redistribute under the license terms.
- **Non-production use** — free for development, testing, evaluation, and internal proof-of-concept.
- **Production use** — requires a commercial license from UiGraph. Production use means any use that supports the ongoing operation of your business or organization.
- **Future open source** — each version converts to [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0) four years after it's first published under BUSL.

BUSL is not an OSI-approved open source license during the initial term. For commercial licensing questions, open an issue or contact the maintainers.

## Related projects

- [uigraph-api](https://github.com/uigraph-oss/uigraph-api) — backend API
- [uigraph-ui](https://github.com/uigraph-oss/uigraph-ui) — web application
- [uigraph-graphql](https://github.com/uigraph-oss/uigraph-graphql) — GraphQL BFF
- [uigraph-gateway](https://github.com/uigraph-oss/uigraph-gateway) — CLI sync API
- [uigraph-mcp](https://github.com/uigraph-oss/uigraph-mcp) — MCP server for AI assistants
- [uigraph-sdk](https://github.com/uigraph-oss/uigraph-sdk) — TypeScript SDK
