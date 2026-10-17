# NetBird Connect

A GitHub Action that joins a Linux runner to a [NetBird](https://netbird.io) network as an ephemeral peer, so later steps can reach private hosts.

> Not made or supported by NetBird.

It installs a pinned NetBird release, checks its SHA-256, and connects with a setup key passed through the environment. The management URL is masked in the log.

By default the runner keeps its own DNS and routes, accepts no inbound connections and routes for no one, so reach private hosts by their NetBird IP.

## Usage

```yaml
- uses: DonQuinleone/netbird-action@<commit sha>
  with:
    setup-key: ${{ secrets.NETBIRD_SETUP_KEY }}
    management-url: ${{ secrets.NETBIRD_MANAGEMENT_URL }}
    wait-for: 100.64.0.10:443
```

| Input | Required | Default |
|-------|----------|---------|
| `setup-key` | yes | |
| `management-url` | yes | |
| `hostname` | no | `gh-<repo>-<run id>-<attempt>` |
| `wait-for` | no | waits for the management connection |
| `accept-dns` | no | `false` |
| `accept-routes` | no | `false` |
| `timeout` | no | `60` seconds |
| `version` | no | the pinned release |
| `checksum` | with `version` | |

## NetBird setup

1. Create a setup key that is **reusable** and **ephemeral**, with an expiry, and auto-assign a group such as `ci`. NetBird removes ephemeral peers 10 minutes after they go offline, which a GitHub-hosted runner does when the job ends.
2. Add a one-way policy from `ci` to the hosts the job needs, limited to their ports.
3. Delete the `Default` policy if it still exists. It lets every peer reach every other.

Use GitHub-hosted runners only. On a self-hosted runner the peer stays connected after the job.

## Test

```bash
tests/run.sh
```

## Licence

MIT. See [LICENSE](LICENSE).
