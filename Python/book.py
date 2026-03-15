#!/usr/bin/env python3
"""
MyBOS – Meeting Room 3 Auto-Booker
Books Mon–Fri 08:00–17:00 for the next 4 weeks (platform max).

Usage:
    python book.py              # book everything available
    python book.py --dry-run   # preview without submitting
    python book.py --yes       # skip per-batch confirmation
"""

import requests
import json
import sys
import argparse
import os
import time
import random
from datetime import date, timedelta

# ─── CONFIG ───────────────────────────────────────────────────────────────────
EMAIL    = os.environ.get("MYBOS_EMAIL",    "")
PASSWORD = os.environ.get("MYBOS_PASSWORD", "")

AMENITY_ID   = "66679a76a3f946d03c0c8ffc"
AMENITY_NAME = "Meeting Room 3"

TARGET_SLOTS = [
    "08:00-09:00", "09:00-10:00", "10:00-11:00",
    "11:00-12:00", "12:00-13:00", "13:00-14:00",
    "14:00-15:00", "15:00-16:00", "16:00-17:00",
]

# booking window is now read from the amenity's booking_available_days field

# ─── RATE LIMITING ────────────────────────────────────────────────────────────
DELAY_BETWEEN_REQUESTS = 1.5   # seconds between every API call
DELAY_BETWEEN_BOOKINGS = 3.0   # extra pause after each booking/save
DELAY_ON_ERROR         = 10.0  # back-off on any non-200 response
# ──────────────────────────────────────────────────────────────────────────────

BASE_URL = "https://app.v4.mybos.com/be/api/v4"

SESSION_HEADERS = {
    "app-mb":            "__@mbv4vbm@__",
    "Content-Type":      "application/json",
    "Accept":            "application/json, text/plain, */*",
    "Accept-Language":   "en-GB,en;q=0.9,en-US;q=0.8,de;q=0.7,de-DE;q=0.6",
    "Accept-Encoding":   "gzip, deflate, br, zstd",
    "Origin":            "https://app.v4.mybos.com",
    "Referer":           "https://app.v4.mybos.com/resident/amenity",
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


def pause(seconds: float, label: str = "") -> None:
    jitter = seconds * random.uniform(0.7, 1.3)
    if label:
        print(f"    ⏳ waiting {jitter:.1f}s {label}…", end=" ", flush=True)
    time.sleep(jitter)
    if label:
        print("done")


def login(session: requests.Session) -> None:
    resp = session.post(f"{BASE_URL}/auth/login", json={
        "username": EMAIL,
        "password": PASSWORD,
        "remember": False,
        "modes": ["BUILDING MANAGER", "RESIDENT", "COMMUNITY",
                  "COMPANY", "COMPANY BUILDING MANAGER"],
    })
    resp.raise_for_status()
    token = resp.json().get("access_token")
    if not token:
        raise RuntimeError(f"No access_token in login response: {resp.text[:300]}")
    session.headers["Authorization"] = f"Bearer {token}"
    print("✅ Logged in — JWT token acquired")
    pause(DELAY_BETWEEN_REQUESTS)


def get_amenity(session: requests.Session) -> dict:
    resp = session.post(f"{BASE_URL}/resident/amenity/single",
                        json={"_id": AMENITY_ID})
    resp.raise_for_status()
    amenity = resp.json()
    print(f"✅ Amenity loaded: {amenity.get('name')}")
    pause(DELAY_BETWEEN_REQUESTS)
    return amenity


def get_profile(session: requests.Session) -> dict:
    resp = session.post(f"{BASE_URL}/resident/profile/me",
                        json={"enablePendo": False, "enableAvatar": False})
    resp.raise_for_status()
    profile = resp.json()
    print(f"✅ Profile loaded: {profile.get('first_name')} {profile.get('last_name')}")
    pause(DELAY_BETWEEN_REQUESTS)
    return profile


def get_enabled_dates(session: requests.Session, month: int, year: int) -> set:
    resp = session.post(
        f"{BASE_URL}/resident/amenity/booking/{AMENITY_ID}",
        params={"month": month, "year": year},
        json={"id": AMENITY_ID, "m": month, "y": year},
    )
    resp.raise_for_status()
    pause(DELAY_BETWEEN_REQUESTS)
    return set(resp.json().get("enabled_dates", []))


def get_slots(session: requests.Session, date_str: str, verbose: bool = False) -> dict:
    resp = session.post(
        f"{BASE_URL}/resident/amenity/booking/{AMENITY_ID}/{date_str}",
        json={"id": AMENITY_ID, "date": date_str},
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
    resp = session.post(f"{BASE_URL}/resident/amenity/booking/save", json=payload)
    if resp.status_code == 200:
        try:
            msg = resp.json().get("message", "OK")
        except Exception:
            msg = resp.text[:80] if resp.text.strip() else "OK (empty body)"
        print(f"    ✅ {msg}")
        pause(DELAY_BETWEEN_BOOKINGS, "after booking")
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
    parser = argparse.ArgumentParser(description="MyBOS Meeting Room 3 auto-booker")
    parser.add_argument("--dry-run", action="store_true",
                        help="Preview without actually booking")
    parser.add_argument("--yes", "-y", action="store_true",
                        help="Skip confirmation prompts")
    parser.add_argument("--email", "-u", default=None,
                        help="MyBOS login email (overrides MYBOS_EMAIL env var)")
    parser.add_argument("--password", "-p", default=None,
                        help="MyBOS login password (overrides MYBOS_PASSWORD env var)")
    args = parser.parse_args()

    # Allow CLI credentials to override env vars
    global EMAIL, PASSWORD
    if args.email:
        EMAIL = args.email
    if args.password:
        PASSWORD = args.password

    if not EMAIL or not PASSWORD:
        print("❌ Credentials required. Provide via:")
        print("   --email EMAIL --password PASSWORD")
        print("   or set MYBOS_EMAIL / MYBOS_PASSWORD environment variables")
        sys.exit(1)

    session = requests.Session()
    session.headers.update(SESSION_HEADERS)
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
          f"{DELAY_BETWEEN_BOOKINGS}s after each booking\n")

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
    print(f"\n🚀 Phase 2 — booking ({DELAY_BETWEEN_BOOKINGS}s cooldown between saves)…\n")
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
