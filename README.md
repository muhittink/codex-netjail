# codex-netjail

Runs Codex CLI with a local model in a network namespace that has no route
out. The only exits are a CONNECT proxy that lets through an allowlist of
`host:port` pairs, and a bridge to the local Ollama port. Everything else is
refused and logged. No root needed.

It is built for local models only. It is not meant for use with ChatGPT or
the OpenAI API: allowing `chatgpt.com` or `api.openai.com` while blocking
the rest of Codex's traffic is outside its purpose and untested.

If you set nothing: Codex runs as `codex --oss --local-provider ollama`, may
reach `127.0.0.1:11434` and nothing else: every other connection attempt is
denied and written to
`~/.local/state/codex-netjail/connect.log`.

```sh
make install && make check
codex-netjail
CODEX_NETJAIL_ALLOW="mcp.example.org:443" codex-netjail exec "summarise README.md"
```

| Variable | Default | Meaning |
|---|---|---|
| `CODEX_NETJAIL_ALLOW` | empty | space-separated `host:port` the proxy lets through; empty denies all |
| `CODEX_NETJAIL_OLLAMA` | `127.0.0.1:11434` | local model endpoint bridged into the namespace |
| `CODEX_NETJAIL_CMD` | `codex --oss --local-provider ollama` | command run inside; arguments are appended |
| `CODEX_NETJAIL_LOG` | `~/.local/state/codex-netjail/connect.log` | ALLOW / DENY / FAIL per connection |

## How it works

1. `unshare --user --map-root-user --net` creates a namespace with only `lo`.
2. On the host, `netjail_relay.py` serves the allowlist proxy and the Ollama
   forwarder on Unix sockets in `$XDG_RUNTIME_DIR`.
3. Inside, two bridges map `127.0.0.1:3128` and the Ollama port onto those
   sockets; `HTTPS_PROXY` points Codex at the proxy.
4. A nested user namespace maps your uid back, so the D-Bus keyring works.

A program that ignores `HTTPS_PROXY` gets no connection at all, because the
namespace has no route. The proxy decides on the CONNECT target only, so an
allowed host could still be used as a relay by something running inside.

## Known limits

- Measured once, 2026-10-21, Codex CLI 0.163.0, with a fake Ollama endpoint:
  five attempts to `chatgpt.com:443` were denied, one of them from
  `world_state.build`. What those requests carry was not seen (TLS).
- Not run against a real Ollama model or in the interactive TUI.
- Only HTTPS via CONNECT is allowed; plain-HTTP targets are always denied.
- Ollama itself runs outside the jail; model pulls go to its registry
  unfiltered.
- `make check` needs `example.com` reachable for its positive control;
  `CHECK_ALLOWED_HOST` points it elsewhere.

## License

0BSD (Zero-Clause BSD), see `LICENSE`: use it for anything, no attribution
required.
