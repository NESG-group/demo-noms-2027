# NOMS 2027 demo

Vertical slice of VIGILANT for the NOMS 2027
demo paper: an analyst question in Open WebUI becomes a **fixed, audited
tshark filter** over a stored capture, and the LLM answers from that evidence.
This repository contains only what that flow needs.

```
Open WebUI -> vigilant-backend (FastAPI) -> Hermes Agent -> Ollama
                    |  sanitise, stage attachments,  |
                    |  prepend scope prompt          |
                    +--------- MCP (/mcp) -----------+
                       pcap_tcp / pcap_arp / ... -> tshark -> audit line
```

## The flow

1. The analyst asks in Open WebUI (`docker-compose.dev-ui.yml`).
2. The API ([chat.py](src/vigilant/api/v1/chat.py)) stages attachments
   outside the conversation ([staging.py](src/vigilant/api/v1/pcap/staging.py):
   the model only sees a `pcap_ref`) and prepends the scope prompt
   ([scope.py](src/vigilant/services/scope.py)).
3. Hermes offers the model its skills and the MCP tools of
   [server.py](src/vigilant/mcp/server.py).
4. The model loads the `pcap-filter` skill
   ([SKILL.md](hermes/skills/security/pcap-filter/SKILL.md)) and picks a view
   (`pcap_tcp`, `pcap_arp`, ...).
5. The view ([filter_pcaps.py](src/vigilant/mcp/tools/filter_pcaps.py)) runs a
   hard-coded display filter and logs one audit line, independent of what the
   model later says:
   ```
   PCAP_VIEW_APPLIED {"capture_id": "...", "tool": "pcap_tcp", "display_filter": "tcp && !icmp && !icmpv6", ...}
   ```
6. The model answers using that evidence.

| View | Fixed display filter |
| --- | --- |
| `pcap_tcp` | `tcp && !icmp && !icmpv6` |
| `pcap_udp` | `udp && !icmp && !icmpv6` |
| `pcap_arp` | `arp` |
| `pcap_ip` | `ip` |

## Run it

### Requirements

- Linux with an NVIDIA GPU, Docker with Compose v2, the
  [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/),
  `make` and `openssl`.
- Enough GPU memory for Qwen 2.5 72B with a 64K context (the model alone is
  47 GB), and about 60 GB of free disk for the images and the model.
- Free ports 3000, 5432, 8000, 8642, 9119 and 11435.

All images are pinned in `docker-compose.yml` and `docker-compose.dev-ui.yml`
to the versions used for the paper results.

### Start the system

```bash
git clone https://github.com/NESG-group/demo-noms-2027.git && cd demo-noms-2027
make env            # creates .env: random Hermes API key and your UID/GID
make up             # postgres, ollama, hermes, backend
make ollama-model   # pulls qwen2.5:72b (about 47 GB, only the first time)
make up-ui          # Open WebUI
```

The backend applies the datalake schema on start. Check that the chain works
end to end; it should list the `hermes-agent` model:

```bash
curl -s http://localhost:8000/v1/models
```

If it fails, look at `docker logs vigilant-hermes` and
`docker logs vigilant-backend`.

### Ask the questions

1. Open http://localhost:3000. The first time, Open WebUI asks you to create
   an admin account; it is local to your machine.
2. Pick the `hermes-agent` model.
3. Attach [`data/demo/nmap22-23-53-80-443-threewayhandshake.pcapng`](data/README.md)
   to the chat and ask one of the questions in
   [data/demo/scenarios.md](data/demo/scenarios.md), the scenarios used in the
   paper. That file also has the expected answers.

To see which views the model applied (one line per view call, written by the
backend whatever the model says):

```bash
docker logs vigilant-backend 2>&1 | grep PCAP_VIEW_APPLIED
```

To see the tokens used by each question (`N=20` for more rows, `ALL=1` to
include Open WebUI's own background requests):

```bash
make tokens
```

To stop everything: `make down`. Data and the model stay in Docker volumes.

## Development

```bash
uv sync --all-groups
make test lint
```

The sensor, the ingest-time actor analysis and the evaluation scripts of the
full project are intentionally not part of this repository.
