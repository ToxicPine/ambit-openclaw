# 🦞☁️ OpenClaw on Ambit

An [Ambit](https://github.com/cardelli/ambit) template that deploys your personal [OpenClaw](https://openclaw.ai) AI gateway onto Fly.io, inside your private Tailscale network.

```bash
ambit create lab
ambit deploy openclaw.lab --template ToxicPine/ambit-openclaw
fly secrets set OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32)
```

Then open `http://openclaw.lab:18789` on any Tailscale-connected device.

## Why

Running the OpenClaw Gateway 24/7 on your laptop is inconvenient, and hosting it on the public internet means your personal assistant's control plane is exposed to anyone who finds the address. Ambit sidesteps both problems by deploying your gateway as "cloud localhost": it runs in the cloud but is only reachable from devices you have enrolled in Tailscale. No public IP is allocated, so there is nothing to harden or audit.

The included [`ambit-skills`](https://github.com/ToxicPine/ambit-skills) submodule is automatically wired into OpenClaw's skill registry on boot, so you can ask your assistant to deploy new apps and it will drop them into your private Ambit network rather than the public internet.

State, configuration, and logs live on a persistent Fly.io volume so nothing is lost across restarts or redeploys. The NixOS/Home Manager setup in this repo makes the container environment fully reproducible.

## Usage

### Deploy

If you do not have an Ambit network yet, create one first:

```bash
ambit create lab
```

Then deploy this template into it:

```bash
ambit deploy openclaw.lab --template ToxicPine/ambit-openclaw
```

### Set Secrets

Non-loopback binds require a gateway token. Set it along with your model and channel credentials before the gateway starts:

```bash
# Required: authenticates the Control UI and secures the non-loopback bind
fly secrets set OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32)

# Model provider (at least one required)
fly secrets set ANTHROPIC_API_KEY=sk-ant-...
fly secrets set OPENAI_API_KEY=sk-...

# Channel tokens — prefer env vars over putting them in openclaw.json
fly secrets set DISCORD_BOT_TOKEN=MTQ...
fly secrets set TELEGRAM_BOT_TOKEN=123456:ABCDEF
```

### Create Your Config

SSH into the machine and write your config to the persistent volume:

```bash
fly ssh console -a openclaw
```

```bash
cat > /data/homes/user/.openclaw/openclaw.json << 'EOF'
{
  "agents": {
    "defaults": {
      "model": { "primary": "anthropic/claude-opus-4-6" }
    }
  },
  "channels": {
    "discord": { "enabled": true },
    "telegram": { "enabled": true }
  }
}
EOF
```

Then restart to apply it:

```bash
fly machine restart -a openclaw
```

### Access the Control UI

Open `http://openclaw.lab:18789` on any Tailscale-connected device. Paste your `OPENCLAW_GATEWAY_TOKEN` to authenticate. From here you can manage channels, sessions, and WebChat.

## Webhooks and Private Deployment

Because Ambit allocates no public IPs, inbound webhook callbacks cannot reach the machine directly. For channels that poll or use long-polling (Discord, Telegram in polling mode, WhatsApp via Baileys) this is not an issue. For channels that push events via webhooks you have two options:

**Tailscale Funnel** exposes a specific path from the gateway through Tailscale's infrastructure without giving the machine a public IP. Configure it under `gateway.tailscale` in `openclaw.json`.

**ngrok** can run as a sidecar inside the container. Add it to `system.nix` as a background daemon and point your webhook provider at the ngrok URL. Set `webhookSecurity.allowedHosts` in your channel config to the ngrok hostname so forwarded host headers are accepted.

## What's in the Repo

| File | Purpose |
|---|---|
| `fly.toml` | Fly.io app config: 16 GB persistent volume, `shared-cpu-2x` VM, gateway bound to port 18789, auto-stop disabled so the gateway stays alive. |
| `flake.nix` | Entry point for the Nix build. Composes system and per-user Home Manager configs into a Docker image. |
| `system.nix` | System-level packages and the gateway entrypoint command. Add daemons here (e.g. `signal-cli`, `ngrok`) if your setup needs them. |
| `home.nix` | Per-user shell environment, aliases, and session variables. |
| `users.nix` | User definitions. Drop per-user Home Manager overrides here (git identity, extra packages, etc.). |

## Customising

To add OS packages (e.g. `ffmpeg`, `signal-cli`), append them to the `packages` list in `system.nix`.

To customise the shell environment or install per-user tools, edit `home.nix` or add a `home` override in `users.nix`.

To add more skills, either add another submodule under `skills/` following the same bundle layout or drop a `SKILL.md` file into `~/.openclaw/workspace/skills/<name>/` on the running machine.

## Troubleshooting

**Gateway won't start after a restart.** A stale PID lock file on the volume can block startup. Delete it and restart:

```bash
fly ssh console --command "rm -f /data/homes/user/.openclaw/gateway.*.lock" -a openclaw
fly machine restart -a openclaw
```

**Out of memory.** The default VM is `shared-cpu-2x` with 2 GB, which is the recommended minimum. If you are running additional daemons (signal-cli, a local model server) bump it:

```bash
fly machine update <machine-id> --vm-memory 4096 -a openclaw
```

**Config changes not being picked up.** Verify the file is on the volume and not the container filesystem, then restart:

```bash
fly ssh console --command "cat /data/homes/user/.openclaw/openclaw.json" -a openclaw
fly machine restart -a openclaw
```

## Building Your Own Image

If you modify the Nix configuration you can build and push a new image with the provided `Justfile`:

```bash
just push-dockerhub  # pushes to Docker Hub as cardellier/openclaw:latest
just push-fly        # pushes directly to your Fly.io registry
```

Update the `[build] image` field in `fly.toml` to point at your image before the next `ambit deploy`.

---

For OpenClaw configuration options see the [OpenClaw docs](https://docs.openclaw.ai). For Ambit network management see the [Ambit README](https://github.com/cardelli/ambit).
