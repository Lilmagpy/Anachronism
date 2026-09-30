"""Shared test configuration.

Every test runs with outbound network connections blocked, because no test may reach the
network (brief §12): LLM behaviour is tested with a fake provider instead.
"""

from __future__ import annotations

import socket
from typing import Any, NoReturn

import pytest

_real_connect = socket.socket.connect
_real_connect_ex = socket.socket.connect_ex
_LOCAL_FAMILY = getattr(socket, "AF_UNIX", None)


def _refuse() -> NoReturn:
    raise RuntimeError("Tests must not use the network; use the fake LLM provider instead.")


def _guarded_connect(sock: socket.socket, address: Any) -> None:
    if sock.family != _LOCAL_FAMILY:
        _refuse()
    _real_connect(sock, address)


def _guarded_connect_ex(sock: socket.socket, address: Any) -> int:
    if sock.family != _LOCAL_FAMILY:
        _refuse()
    return _real_connect_ex(sock, address)


@pytest.fixture(autouse=True)
def _block_network(monkeypatch: pytest.MonkeyPatch) -> None:
    """Make every outbound network connection fail loudly (local Unix sockets stay allowed)."""
    monkeypatch.setattr(socket.socket, "connect", _guarded_connect)
    monkeypatch.setattr(socket.socket, "connect_ex", _guarded_connect_ex)
