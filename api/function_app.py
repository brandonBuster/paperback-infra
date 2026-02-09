"""Alpaca paper trading API - buy/sell orders via HTTP trigger."""

import json
import logging
import os
from typing import Literal

import azure.functions as func
import requests

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)

ALPACA_BASE = os.environ.get("ALPACA_BASE_URL", "https://paper-api.alpaca.markets")
ALPACA_KEY = os.environ.get("ALPACA_API_KEY", "")
ALPACA_SECRET = os.environ.get("ALPACA_SECRET_KEY", "")


def _alpaca_headers() -> dict:
    return {
        "APCA-API-KEY-ID": ALPACA_KEY,
        "APCA-API-SECRET-KEY": ALPACA_SECRET,
        "Content-Type": "application/json",
    }


def _bad_request(msg: str) -> func.HttpResponse:
    return func.HttpResponse(
        json.dumps({"error": msg}),
        status_code=400,
        mimetype="application/json",
    )


def _place_order(
    symbol: str,
    qty: float,
    side: Literal["buy", "sell"],
    limit_price: float,
    time_in_force: str = "gtc",
) -> tuple[int, dict]:
    """Place a limit order with Alpaca paper API."""
    url = f"{ALPACA_BASE}/v2/orders"
    payload = {
        "symbol": symbol.upper(),
        "qty": str(int(qty)) if qty == int(qty) else str(qty),
        "side": side,
        "type": "limit",
        "limit_price": str(limit_price),
        "time_in_force": time_in_force,
    }
    resp = requests.post(url, json=payload, headers=_alpaca_headers(), timeout=30)
    try:
        body = resp.json()
    except Exception:
        body = {"error": resp.text}
    return resp.status_code, body


@app.route(route="orders", methods=["POST"], auth_level=func.AuthLevel.FUNCTION)
def orders(req: func.HttpRequest) -> func.HttpResponse:
    """
    Place a buy or sell order.

    Body: {
        "action": "buy" | "sell",
        "symbol": "AAPL",
        "quantity": 10,
        "target_price": 150.50
    }
    """
    logging.info("Orders request received")

    if not ALPACA_KEY or not ALPACA_SECRET:
        return func.HttpResponse(
            json.dumps({"error": "Alpaca credentials not configured. Add ALPACA-API-KEY and ALPACA-SECRET-KEY to Key Vault."}),
            status_code=503,
            mimetype="application/json",
        )

    try:
        body = req.get_json()
    except ValueError:
        return _bad_request("Invalid JSON body")

    if not body:
        return _bad_request("Request body required")

    action = (body.get("action") or "").lower()
    symbol = (body.get("symbol") or "").strip()
    quantity = body.get("quantity")
    target_price = body.get("target_price")

    for ok, msg in [
        (action in ("buy", "sell"), "action must be 'buy' or 'sell'"),
        (bool(symbol), "symbol is required"),
        (quantity is not None, "quantity is required"),
        (target_price is not None, "target_price is required"),
    ]:
        if not ok:
            return _bad_request(msg)

    try:
        qty = float(quantity)
        if qty <= 0:
            raise ValueError()
    except (TypeError, ValueError):
        return _bad_request("quantity must be a positive number")
    try:
        price = float(target_price)
        if price <= 0:
            raise ValueError()
    except (TypeError, ValueError):
        return _bad_request("target_price must be a positive number")

    status, result = _place_order(
        symbol=symbol,
        qty=qty,
        side=action,
        limit_price=price,
    )

    return func.HttpResponse(
        json.dumps(result),
        status_code=status,
        mimetype="application/json",
    )
