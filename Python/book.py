#!/usr/bin/env python3
"""
Meeting Room 3 Auto-Booker
Books Mon–Fri 08:00–17:00 for the next 4 weeks (platform max).

Usage:
    python book.py              # book everything available
    python book.py --dry-run    # preview without submitting
    python book.py --yes        # skip per-batch confirmation
"""

import argparse
import base64
import hashlib
import json
import os
import random
import re
import secrets
import sys
import time
from datetime import date, timedelta
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

import requests


ENV_FILE = Path(__file__).with_name(".env")

# ─── CONFIG ───────────────────────────────────────────────────────────────────
EMAIL    = os.environ.get("BOOKER_EMAIL", "")
PASSWORD = os.environ.get("BOOKER_PASSWORD", "")
BASE_URL = os.environ.get("BOOKER_BASE_URL", "")
OAUTH_AUTH_URL = os.environ.get("BOOKER_AUTH_URL", "").rstrip("/")
OAUTH_CLIENT_ID = os.environ.get("BOOKER_OAUTH_CLIENT_ID", "")
OAUTH_ACCESS_COOKIE = os.environ.get("BOOKER_OAUTH_ACCESS_COOKIE", "")
OAUTH_LOGIN_TOKEN_RE = re.compile(r'name="_token" value="([^"]+)"')

AMENITY_ID   = "66679a76a3f946d03c0c8ffc"
AMENITY_NAME = "Meeting Room 3"

TARGET_SLOTS = [
    "08:00-09:00", "09:00-10:00", "10:00-11:00",
    "11:00-12:00", "12:00-13:00", "13:00-14:00",
    "14:00-15:00", "15:00-16:00", "16:00-17:00",
]

# booking window is now read from the amenity's booking_available_days field

# ─── RATE LIMITING ────────────────────────────────────────────────────────────
DELAY_BETWEEN_REQUESTS     = 1.5   # seconds between every API call
MIN_DELAY_BETWEEN_BOOKINGS = 16.0  # random pause after booking/save
MAX_DELAY_BETWEEN_BOOKINGS = 59.0  # random pause after booking/save
DELAY_ON_ERROR             = 10.0  # back-off on any non-200 response
# ──────────────────────────────────────────────────────────────────────────────

SESSION_HEADERS = {
    "app-mb":            "__@mbv4vbm@__",
    "Content-Type":      "application/json",
    "Accept":            "application/json, text/plain, */*",
    "Accept-Language":   "en-GB,en;q=0.9,en-US;q=0.8,de;q=0.7,de-DE;q=0.6",
    "Accept-Encoding":   "gzip, deflate, br, zstd",
    "Cache-Control":     "no-cache",
    "Pragma":            "no-cache",
    "sec-ch-ua":         '"Not:A-Brand";v="99", "Microsoft Edge";v="145", "Chromium";v="145"',
    "sec-ch-ua-mobile":  "?0",
    "sec-ch-ua-platform": '"macOS"',
    "sec-fetch-dest":    "empty",
    "sec-fetch-mode":    "cors",
    "sec-fetch-site":    "same-origin",
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0"
    ),
}


def app_url_from_base(base_url: str) -> str:
    parts = urlsplit(base_url)
    if not parts.scheme or not parts.netloc:
        return ""
    return f"{parts.scheme}://{parts.netloc}"


def oauth_authorize_url(auth_url: str) -> str:
    return f"{auth_url}/oauth/authorize"


def oauth_login_url(auth_url: str) -> str:
    return f"{auth_url}/login"


def code_verifier() -> str:
    return base64.urlsafe_b64encode(secrets.token_bytes(48)).decode().rstrip("=")


def code_challenge(verifier: str) -> str:
    digest = hashlib.sha256(verifier.encode("utf-8")).digest()
    return base64.urlsafe_b64encode(digest).decode().rstrip("=")


def get_cookie_value(session: requests.Session, name: str) -> str:
    for cookie in session.cookies:
        if cookie.name == name:
            return cookie.value
    return ""


def oauth_session_from(session: requests.Session) -> requests.Session:
    auth_session = requests.Session()
    for header in (
        "User-Agent",
        "Accept-Language",
        "Accept-Encoding",
        "sec-ch-ua",
        "sec-ch-ua-mobile",
        "sec-ch-ua-platform",
    ):
        if header in session.headers:
            auth_session.headers[header] = session.headers[header]
    auth_session.headers["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
    return auth_session


def extract_oauth_code(url: str, expected_state: str, *, required: bool) -> str:
    query = parse_qs(urlsplit(url).query)
    error = query.get("error", [""])[0]
    if error:
        description = query.get("error_description", [""])[0]
        if description:
            raise RuntimeError(f"OAuth authorize failed: {error} ({description})")
        raise RuntimeError(f"OAuth authorize failed: {error}")

    code = query.get("code", [""])[0]
    if not code:
        if required:
            raise RuntimeError(
                f"OAuth login did not reach callback URL. Final URL: {url}"
            )
        return ""

    returned_state = query.get("state", [""])[0]
    if returned_state != expected_state:
        raise RuntimeError("OAuth state mismatch during login")
    return code


def load_env_file(env_file: Path) -> None:
    if not env_file.is_file():
        return

    for raw_line in env_file.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[7:].strip()
        if "=" not in line:
            continue

        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if not key:
            continue
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
            value = value[1:-1]
        os.environ.setdefault(key, value)


def refresh_config_from_env() -> None:
    global EMAIL, PASSWORD, BASE_URL, OAUTH_AUTH_URL, OAUTH_CLIENT_ID, OAUTH_ACCESS_COOKIE
    EMAIL = os.environ.get("BOOKER_EMAIL", "")
    PASSWORD = os.environ.get("BOOKER_PASSWORD", "")
    BASE_URL = os.environ.get("BOOKER_BASE_URL", "")
    OAUTH_AUTH_URL = os.environ.get("BOOKER_AUTH_URL", "").rstrip("/")
    OAUTH_CLIENT_ID = os.environ.get("BOOKER_OAUTH_CLIENT_ID", "")
    OAUTH_ACCESS_COOKIE = os.environ.get("BOOKER_OAUTH_ACCESS_COOKIE", "")


def pause(seconds: float, label: str = "") -> None:
    jitter = seconds * random.uniform(0.7, 1.3)
    if label:
        print(f"    ⏳ waiting {jitter:.1f}s {label}…", end=" ", flush=True)
    time.sleep(jitter)
    if label:
        print("done")


def pause_range(min_seconds: float, max_seconds: float, label: str = "") -> None:
    wait = random.uniform(min_seconds, max_seconds)
    if label:
        print(f"    ⏳ waiting {wait:.1f}s {label}…", end=" ", flush=True)
    time.sleep(wait)
    if label:
        print("done")


def login(session: requests.Session) -> None:
    app_url = app_url_from_base(BASE_URL)
    if not app_url:
        raise RuntimeError("Invalid base URL")
    if not OAUTH_AUTH_URL:
        raise RuntimeError("Missing BOOKER_AUTH_URL")
    if not OAUTH_CLIENT_ID:
        raise RuntimeError("Missing BOOKER_OAUTH_CLIENT_ID")
    if not OAUTH_ACCESS_COOKIE:
        raise RuntimeError("Missing BOOKER_OAUTH_ACCESS_COOKIE")

    session.headers.pop("Authorization", None)
    auth_session = oauth_session_from(session)
    authorize_url = oauth_authorize_url(OAUTH_AUTH_URL)
    login_url = oauth_login_url(OAUTH_AUTH_URL)

    verifier = code_verifier()
    state = secrets.token_urlsafe(16)
    redirect_uri = f"{app_url}/auth/callback"

    authorize_resp = auth_session.get(
        authorize_url,
        params={
            "client_id": OAUTH_CLIENT_ID,
            "redirect_uri": redirect_uri,
            "response_type": "code",
            "scope": "",
            "state": state,
            "code_challenge": code_challenge(verifier),
            "code_challenge_method": "S256",
        },
        allow_redirects=True,
    )
    authorize_resp.raise_for_status()

    code = extract_oauth_code(authorize_resp.url, state, required=False)
    if not code:
        login_token_match = OAUTH_LOGIN_TOKEN_RE.search(authorize_resp.text)
        if not login_token_match:
            raise RuntimeError(
                f"Could not find OAuth login form token. Final URL: {authorize_resp.url}"
            )

        login_resp = auth_session.post(
            login_url,
            data={
                "_token": login_token_match.group(1),
                "email": EMAIL,
                "password": PASSWORD,
            },
            headers={
                "Content-Type": "application/x-www-form-urlencoded",
                "Origin": OAUTH_AUTH_URL,
                "Referer": authorize_resp.url,
            },
            allow_redirects=True,
        )
        login_resp.raise_for_status()
        code = extract_oauth_code(login_resp.url, state, required=True)

    token_resp = auth_session.post(
        f"{app_url}/oauth/token",
        json={
            "client_id": OAUTH_CLIENT_ID,
            "grant_type": "authorization_code",
            "redirect_uri": redirect_uri,
            "code_verifier": verifier,
            "code": code,
        },
        headers={
            "Origin": app_url,
            "Referer": redirect_uri,
        },
    )
    token_resp.raise_for_status()

    for cookie in auth_session.cookies:
        session.cookies.set_cookie(cookie)

    token = get_cookie_value(session, OAUTH_ACCESS_COOKIE)
    if not token:
        raise RuntimeError(
            "OAuth token cookie missing after token exchange. "
            f"Response was: {token_resp.text[:300]}"
        )

    session.headers["Authorization"] = f"Bearer {token}"
    print("✅ Logged in - OAuth session established")
    pause(DELAY_BETWEEN_REQUESTS)


def api_post(
    session: requests.Session,
    path: str,
    *,
    payload: dict,
    params: dict | None = None,
) -> requests.Response:
    resp = session.post(f"{BASE_URL}{path}", params=params, json=payload)
    if resp.status_code == 401:
        print("    🔐 Session expired, signing in again...")
        login(session)
        resp = session.post(f"{BASE_URL}{path}", params=params, json=payload)
    return resp


def get_amenity(session: requests.Session) -> dict:
    resp = api_post(session, "/resident/amenity/single", payload={"_id": AMENITY_ID})
    resp.raise_for_status()
    amenity = resp.json()
    print(f"✅ Amenity loaded: {amenity.get('name')}")
    pause(DELAY_BETWEEN_REQUESTS)
    return amenity


def get_profile(session: requests.Session) -> dict:
    resp = api_post(
        session,
        "/resident/profile/me",
        payload={"enablePendo": False, "enableAvatar": False},
    )
    resp.raise_for_status()
    profile = resp.json()
    print(f"✅ Profile loaded: {profile.get('first_name')} {profile.get('last_name')}")
    pause(DELAY_BETWEEN_REQUESTS)
    return profile


def get_enabled_dates(session: requests.Session, month: int, year: int) -> set:
    resp = api_post(
        session,
        f"/resident/amenity/booking/{AMENITY_ID}",
        params={"month": month, "year": year},
        payload={"id": AMENITY_ID, "m": month, "y": year},
    )
    resp.raise_for_status()
    pause(DELAY_BETWEEN_REQUESTS)
    return set(resp.json().get("enabled_dates", []))


def get_slots(session: requests.Session, date_str: str, verbose: bool = False) -> dict:
    resp = api_post(
        session,
        f"/resident/amenity/booking/{AMENITY_ID}/{date_str}",
        payload={"id": AMENITY_ID, "date": date_str},
    )
    if resp.status_code != 200:
        print(f"    ⚠️  slot check returned {resp.status_code}, backing off {DELAY_ON_ERROR}s")
        pause(DELAY_ON_ERROR)
        return {}
    pause(DELAY_BETWEEN_REQUESTS)
    data = resp.json().get("data", [])
    if verbose:
        print(f"    📋 Raw slot data for {date_str}:")
        for s in data:
            icon = "🟢" if s.get("status") else "🔴"
            print(f"       {icon} {s['time']:14s}  status={s.get('status')}  available_slots={s.get('available_slots')}")
    # status=True → available/bookable; status=False → already booked
    return {s["time"]: s["status"] for s in data}


def book(session: requests.Session, amenity: dict, profile: dict,
         date_str: str, slots: list, dry_run: bool) -> bool:
    payload = {
        **amenity,
        "amenity_id": AMENITY_ID,
        "date": date_str,
        "time": slots,
        "booker_first_name": profile.get("first_name", ""),
        "booker_last_name":  profile.get("last_name", ""),
        "booker_email":      profile.get("email", ""),
        "booker_mobile":     profile.get("mobile", ""),
        "booker_phone":      profile.get("phone", ""),
    }
    if dry_run:
        print(f"    🔍 DRY RUN → {date_str}: {slots}")
        pause(0.2)
        return True
    resp = api_post(session, "/resident/amenity/booking/save", payload=payload)
    if resp.status_code == 200:
        try:
            msg = resp.json().get("message", "OK")
        except Exception:
            msg = resp.text[:80] if resp.text.strip() else "OK (empty body)"
        print(f"    ✅ {msg}")
        pause_range(MIN_DELAY_BETWEEN_BOOKINGS, MAX_DELAY_BETWEEN_BOOKINGS, "after booking")
        return True
    else:
        print(f"    ❌ {resp.status_code}: {resp.text[:200]}")
        pause(DELAY_ON_ERROR, "back-off after error")
        return False


def weekdays_in_range(start: date, end: date, reverse: bool = False):
    days = []
    d = start
    while d <= end:
        if d.weekday() < 5:
            days.append(d)
        d += timedelta(days=1)
    return reversed(days) if reverse else iter(days)


def confirm(prompt: str) -> bool:
    try:
        answer = input(f"{prompt} [y/N] ").strip().lower()
    except (EOFError, KeyboardInterrupt):
        print()
        return False
    return answer in ("y", "yes")


def main():
    parser = argparse.ArgumentParser(description="Meeting Room 3 auto-booker")
    parser.add_argument("--dry-run", action="store_true",
                        help="Preview without actually booking")
    parser.add_argument("--yes", "-y", action="store_true",
                        help="Skip confirmation prompts")
    parser.add_argument("--email", "-u", default=None,
                        help="Login email (overrides BOOKER_EMAIL env var)")
    parser.add_argument("--password", "-p", default=None,
                        help="Login password (overrides BOOKER_PASSWORD env var)")
    parser.add_argument("--base-url", "-b", default=None,
                        help="API base URL (overrides BOOKER_BASE_URL env var)")
    args = parser.parse_args()

    load_env_file(ENV_FILE)
    refresh_config_from_env()

    # Allow CLI config to override env vars
    global EMAIL, PASSWORD, BASE_URL
    if args.email:
        EMAIL = args.email
    if args.password:
        PASSWORD = args.password
    if args.base_url:
        BASE_URL = args.base_url

    required_config = {
        "BOOKER_EMAIL": EMAIL,
        "BOOKER_PASSWORD": PASSWORD,
        "BOOKER_BASE_URL": BASE_URL,
        "BOOKER_AUTH_URL": OAUTH_AUTH_URL,
        "BOOKER_OAUTH_CLIENT_ID": OAUTH_CLIENT_ID,
        "BOOKER_OAUTH_ACCESS_COOKIE": OAUTH_ACCESS_COOKIE,
    }
    missing_config = [name for name, value in required_config.items() if not value]
    if missing_config:
        print("❌ Missing required configuration:")
        for name in missing_config:
            print(f"   {name}")
        print(f"   Set them in {ENV_FILE}")
        print("   CLI overrides exist for BOOKER_EMAIL / BOOKER_PASSWORD / BOOKER_BASE_URL")
        sys.exit(1)

    app_url = app_url_from_base(BASE_URL)
    if not app_url:
        print("❌ Invalid base URL")
        sys.exit(1)

    session = requests.Session()
    session.headers.update(SESSION_HEADERS)
    session.headers["Origin"] = app_url
    session.headers["Referer"] = f"{app_url}/resident/amenity"
    login(session)

    amenity = get_amenity(session)
    profile = get_profile(session)

    # Use the platform's own booking_available_days limit instead of a hardcoded window
    today = date.today()
    avail_days = int(amenity.get("booking_available_days", 30))
    max_end = today + timedelta(days=avail_days)
    print(f"  ℹ️  Platform allows bookings up to {avail_days} days ahead (until {max_end})")

    # Ask user how many days to scan
    if not args.yes:
        print(f"\n📆 How far ahead do you want to scan for available slots?")
        print(f"   1) Last 1 week  (faster,  ~{min(7, avail_days)}d)")
        print(f"   2) Last 2 weeks (~{min(14, avail_days)}d)")
        print(f"   3) Full {avail_days} days  (slower, until {max_end})")
        try:
            choice = input("   Choice [1/2/3, default=3]: ").strip() or "3"
        except (EOFError, KeyboardInterrupt):
            choice = "3"
        scan_days = {"1": 7, "2": 14}.get(choice, avail_days)
    else:
        scan_days = avail_days

    # Always end at the platform maximum; start is max_end - scan_days (but no earlier than today)
    scan_start = max(today, max_end - timedelta(days=scan_days))
    end = max_end
    print(f"\n📅 Window: {scan_start} → {end} ({(end - scan_start).days}d, newest first)  |  Mon–Fri  |  {TARGET_SLOTS[0]}–{TARGET_SLOTS[-1]}")
    print(f"⏱  Delays: {DELAY_BETWEEN_REQUESTS}s between requests, "
          f"{MIN_DELAY_BETWEEN_BOOKINGS:.0f}-{MAX_DELAY_BETWEEN_BOOKINGS:.0f}s random after each booking\n")

    # ── Phase 1: discovery (read-only) ────────────────────────────────────────
    print("🔍 Phase 1 — checking availability (no bookings yet)…\n")

    enabled_cache: dict[tuple, set] = {}
    plan: list[tuple[date, list]] = []   # (day, slots_to_book)

    for day in weekdays_in_range(scan_start, end, reverse=True):
        key = (day.month, day.year)
        if key not in enabled_cache:
            print(f"  📆 Fetching enabled dates for {day.strftime('%B %Y')}…")
            enabled_cache[key] = get_enabled_dates(session, day.month, day.year)

        date_str = day.strftime("%Y-%m-%d")
        label    = f"{date_str} ({day.strftime('%a')})"

        if date_str not in enabled_cache[key]:
            print(f"  ⏭  {label} — date disabled by platform")
            continue

        slot_avail    = get_slots(session, date_str, verbose=True)
        slots_to_book = [s for s in TARGET_SLOTS if slot_avail.get(s, False) is True]
        taken         = [s for s in TARGET_SLOTS if not slot_avail.get(s, False)]

        if not slots_to_book:
            print(f"  ⏭  {label} — fully booked already")
            continue

        if taken:
            print(f"  ⚠️  {label} — {len(taken)} slot(s) taken, {len(slots_to_book)} free")
        else:
            print(f"  ✔  {label} — {len(slots_to_book)} slots free")

        plan.append((day, slots_to_book))

    # ── Phase 1 summary + gate ─────────────────────────────────────────────
    print(f"\n{'─'*55}")
    print(f"PLAN: {len(plan)} day(s) to book, "
          f"up to {len(plan) * len(TARGET_SLOTS)} slot(s) total")
    for day, slots in plan:
        print(f"  {day.strftime('%Y-%m-%d %a')}  →  {slots[0]} – {slots[-1]}  ({len(slots)} slots)")
    print(f"{'─'*55}\n")

    if not plan:
        print("Nothing to book. Exiting.")
        return

    if args.dry_run:
        print("DRY RUN — no bookings will be made.")
        return

    if not args.yes:
        if not confirm(f"⚡ Proceed and book all {len(plan)} days?"):
            print("Aborted.")
            return

    # ── Phase 2: booking ──────────────────────────────────────────────────────
    print(
        f"\n🚀 Phase 2 — booking "
        f"({MIN_DELAY_BETWEEN_BOOKINGS:.0f}-{MAX_DELAY_BETWEEN_BOOKINGS:.0f}s random cooldown between saves)…\n"
    )
    booked, failed = 0, 0

    for i, (day, slots) in enumerate(plan, 1):
        date_str = day.strftime("%Y-%m-%d")
        print(f"  [{i}/{len(plan)}] {date_str} ({day.strftime('%a')}) — {len(slots)} slots")
        ok = book(session, amenity, profile, date_str, slots, dry_run=False)
        if ok:
            booked += 1
        else:
            failed += 1

    print(f"\n{'─'*55}")
    print(f"DONE: {booked} booked, {failed} failed")


if __name__ == "__main__":
    main()
