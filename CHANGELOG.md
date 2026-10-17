# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [semantic versioning](https://semver.org/).

## [1.0.1] - 2026-10-17

### Changed

- Renamed to NetBird Ephemeral Peer, so the action can be listed on the GitHub Marketplace; "NetBird Connect" was taken.
- Bump pull requests carry a commit signed by GitHub and run the tests without being reopened.

## [1.0.0] - 2026-10-17

### Added

- Join a NetBird network as an ephemeral peer on GitHub-hosted Linux runners, X64 and ARM64.
- Install a pinned NetBird release (0.81.2) and check its SHA-256 before installing; another version needs its checksum.
- Wait for a `host:port` to accept connections, or for the management connection, with a timeout.
- `accept-dns` and `accept-routes` inputs, both off by default.
- A weekly workflow that opens a pull request when NetBird releases a new version.

### Security

- The setup key reaches NetBird through the environment, never the command line, and is masked in the log, as are the management URL and its host.
- By default the runner keeps its own DNS and routes, accepts no inbound connections and routes for no other peer. A nameserver group or route that the runner cannot reach would otherwise break its name resolution.
- Every input is validated before NetBird starts.

[1.0.1]: https://github.com/DonQuinleone/netbird-action/releases/tag/v1.0.1
[1.0.0]: https://github.com/DonQuinleone/netbird-action/releases/tag/v1.0.0
