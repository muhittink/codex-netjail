import asyncio
import os
import sys
import time

FORBIDDEN = b"HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
ESTABLISHED = b"HTTP/1.1 200 Connection established\r\n\r\n"


def record(log_path, verdict, method, target):
    stamp = time.strftime("%Y-%m-%dT%H:%M:%S")
    with open(log_path, "a") as log:
        log.write(f"{stamp} {verdict} {method} {target}\n")


async def pump(reader, writer):
    try:
        while data := await reader.read(65536):
            writer.write(data)
            await writer.drain()
    except (ConnectionError, asyncio.CancelledError):
        pass
    finally:
        writer.close()


async def splice(left_reader, left_writer, right_reader, right_writer):
    await asyncio.gather(
        pump(left_reader, right_writer),
        pump(right_reader, left_writer),
        return_exceptions=True,
    )


async def read_request_line(reader):
    head = await reader.readuntil(b"\r\n\r\n")
    method, target, _ = head.split(b"\r\n", 1)[0].decode("ascii", "replace").split(" ", 2)
    return method, target


async def serve_allowlist_proxy(socket_path, allowed_targets, log_path):
    async def handle(reader, writer):
        try:
            method, target = await read_request_line(reader)
        except (asyncio.IncompleteReadError, ValueError, ConnectionError):
            writer.close()
            return
        if method != "CONNECT" or target not in allowed_targets:
            record(log_path, "DENY", method, target)
            writer.write(FORBIDDEN)
            await writer.drain()
            writer.close()
            return
        host, port = target.rsplit(":", 1)
        try:
            upstream_reader, upstream_writer = await asyncio.open_connection(host, int(port))
        except OSError as error:
            record(log_path, "FAIL", method, f"{target} {error}")
            writer.close()
            return
        record(log_path, "ALLOW", method, target)
        writer.write(ESTABLISHED)
        await writer.drain()
        await splice(reader, writer, upstream_reader, upstream_writer)

    server = await asyncio.start_unix_server(handle, path=socket_path)
    await server.serve_forever()


async def serve_unix_to_tcp(socket_path, host, port):
    async def handle(reader, writer):
        try:
            upstream_reader, upstream_writer = await asyncio.open_connection(host, port)
        except OSError:
            writer.close()
            return
        await splice(reader, writer, upstream_reader, upstream_writer)

    server = await asyncio.start_unix_server(handle, path=socket_path)
    await server.serve_forever()


async def serve_tcp_to_unix(port, socket_path):
    async def handle(reader, writer):
        try:
            upstream_reader, upstream_writer = await asyncio.open_unix_connection(socket_path)
        except OSError:
            writer.close()
            return
        await splice(reader, writer, upstream_reader, upstream_writer)

    server = await asyncio.start_server(handle, "127.0.0.1", port)
    await server.serve_forever()


def split_host_port(address):
    host, port = address.rsplit(":", 1)
    return host, int(port)


def main(argv):
    mode = argv[1]
    if mode == "proxy":
        socket_path, log_path, allowed = argv[2], argv[3], set(argv[4].split())
        asyncio.run(serve_allowlist_proxy(socket_path, allowed, log_path))
    elif mode == "unix-to-tcp":
        host, port = split_host_port(argv[3])
        asyncio.run(serve_unix_to_tcp(argv[2], host, port))
    elif mode == "tcp-to-unix":
        asyncio.run(serve_tcp_to_unix(int(argv[2]), argv[3]))
    else:
        sys.exit(f"unknown mode {mode!r}: use proxy, unix-to-tcp or tcp-to-unix")


if __name__ == "__main__":
    os.umask(0o077)
    main(sys.argv)
