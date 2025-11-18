# Hardened Helm Charts

This repository contains **opinionated, hardened Helm charts** used by Kingdom Tech to deploy application and vendor services into **secure, regulated environments** (e.g. AWS GovCloud `us-gov-west-1` via Palantir Apollo / FedStart).

All charts are:

- Compatible with **Helm v3**
- Targeted at **FIPS-enabled ECR registries** (e.g. `<account_id>.dkr.ecr-fips.us-gov-west-1.amazonaws.com`)
- Structured to work cleanly with **Palantir Rubix / Apollo** annotations and service metadata
- Designed to be driven by **environment-specific values files** (IL5, staging, etc.)
---

## Repository Layout

```text
.
├── README.md                 # This file
├── helm-apollo.sh           # Helper script for publishing charts into Apollo
└── charts/
    ├── app-sidekiq/
    │   └── helm-chart/
    │       ├── Chart.yaml
    │       ├── values.yaml
    │       └── templates/
    │           ├── app-deployment.yaml
    │           ├── app-network.yaml
    │           ├── db-config.yaml
    │           ├── initial-user.yaml
    │           ├── migration-job.yaml
    │           ├── pvc.yaml
    │           └── sidekiq-deployment.yaml
    ├── genai-image/
    │   └── helm-chart/
    │       ├── Chart.yaml
    │       ├── values.yaml
    │       └── templates/
    │           ├── deployment.yaml
    │           ├── service.yaml
    │           └── serviceaccount.yaml
    ├── vendor-analytics/
    │   ├── README.md        # Links to upstream Metabase docs
    │   └── helm-chart/
    │       ├── Chart.yaml
    │       ├── values.yaml
    │       └── templates/
    │           ├── deployment.yaml
    │           └── service.yaml
    ├── vendor-pdf-service/
    │   └── helm-chart/
    │       ├── Chart.yaml
    │       ├── values.yaml
    │       └── templates/
    │           ├── deployment.yaml
    │           └── nginx-deployment.yaml (via templates)
    └── vendor-webspellchecker/
        └── helm-chart/
            ├── Chart.yaml
            ├── values.yaml
            └── templates/
                ├── deployment.yaml
                └── service.yaml
