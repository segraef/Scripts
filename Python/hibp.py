"""Command-line Have I Been Pwned (HIBP) breach checker.

Prompts for an email address and a password, then queries the HIBP API to
report whether the email appears in known data breaches and whether the
password appears in the Pwned Passwords range API. Finally it lists every
breach currently tracked by HIBP.

The HIBP API key is read from the HIBP_API_KEY environment variable (via a
.env file). The script exits with an error if the key is not set.
"""
import os
import hashlib
import getpass

import requests
from dotenv import load_dotenv

# Load the environment variables from .env
load_dotenv()

# Get the API key from the environment variables
API_KEY = os.getenv('HIBP_API_KEY')
if not API_KEY:
    raise RuntimeError('HIBP_API_KEY is not set. Add it to your environment or .env file.')

API_URL = 'https://haveibeenpwned.com/api/v3'
PWD_API_URL = 'https://api.pwnedpasswords.com/range'

# Request timeout (seconds) so a stalled network call doesn't hang the CLI.
REQUEST_TIMEOUT = 10

# HIBP requires both an API key and a descriptive User-Agent.
HIBP_HEADERS = {
    'hibp-api-key': API_KEY,
    'User-Agent': 'segraef-Scripts-hibp-checker',
}

# The Pwned Passwords range API is a separate, unauthenticated service:
# never send the HIBP API key to it.
PWD_HEADERS = {'User-Agent': 'segraef-Scripts-hibp-checker'}


def check_email_breach(email):
    """Check whether an email address appears in known data breaches.

    Args:
        email: The email address to look up.
    """
    try:
        response = requests.get(
            f'{API_URL}/breachedaccount/{email}',
            headers=HIBP_HEADERS,
            timeout=REQUEST_TIMEOUT,
        )
    except requests.RequestException as exc:
        print(f"Error checking email: {exc}")
        return

    # Check the status code of the response
    if response.status_code == 404:
        print("Email not found in data breaches")
    elif response.status_code != 200:
        print("Error checking email")
    else:
        # Extract the name of the breaches from the response
        breaches = [breach['Name'] for breach in response.json()]
        print(f"Email found in following breaches: {', '.join(breaches)}.")


def check_password_breach(password):
    """Check whether a password appears in the Pwned Passwords range API.

    The password is SHA-1 hashed locally and only the first five characters of
    the hash are sent to the API (k-anonymity), so the plaintext never leaves
    this machine.

    Args:
        password: The plaintext password to check.
    """
    # Hash the password before sending it to the HIBP API
    hashed_password = hashlib.sha1(password.encode('utf-8')).hexdigest().upper()
    prefix = hashed_password[:5]
    suffix = hashed_password[5:]

    try:
        response = requests.get(
            f'{PWD_API_URL}/{prefix}',
            headers=PWD_HEADERS,
            timeout=REQUEST_TIMEOUT,
        )
    except requests.RequestException as exc:
        print(f"Error checking password: {exc}")
        return

    # Check the status code of the response
    if response.status_code != 200:
        print("Error checking password")
        return

    # Check if the hashed password suffix exists in the response
    for line in response.text.splitlines():
        line_suffix, count = line.split(':')
        if line_suffix == suffix:
            print(f"Password found {count} times. Please use a different password.")
            break
    else:
        print("Password not found. You can use this password.")


def list_all_breaches():
    """Fetch and print every breach currently tracked by HIBP."""
    try:
        response = requests.get(
            f'{API_URL}/breaches',
            headers=HIBP_HEADERS,
            timeout=REQUEST_TIMEOUT,
        )
    except requests.RequestException as exc:
        print(f"Error fetching breaches: {exc}")
        return

    if response.status_code != 200:
        print(f"Error fetching breaches (HTTP {response.status_code}).")
        return

    # Display the breaches
    breaches = response.json()
    count = len(breaches)
    for breach in breaches:
        print(f'Name: {breach["Name"]}')
        print(f'Title: {breach["Title"]}')
        print(f'Domain: {breach["Domain"]}')
        print(f'Breach date: {breach["BreachDate"]}')
        print('---')
    print(f'Total number of breaches: {count}')


def main():
    """Run the interactive email and password breach checks."""
    # Get the email address from the user input
    email = input("Enter your email address: ")
    check_email_breach(email)

    password = getpass.getpass("Enter your password: ")
    check_password_breach(password)

    list_all_breaches()


if __name__ == '__main__':
    main()
