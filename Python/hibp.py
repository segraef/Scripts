import os, json, hashlib, requests
from dotenv import load_dotenv

# Load the environment variables from .env
load_dotenv()

# Get the API key from the environment variables
API_KEY = os.getenv('HIBP_API_KEY')

api_url = 'https://haveibeenpwned.com/api/v3'
pwd_api_url = 'https://api.pwnedpasswords.com/range'

# Get the email address from the user input
email = input("Enter your email address: ")

# Use the API key in the headers
headers = {'hibp-api-key': API_KEY}

# Send the GET request to the HIBP API
response = requests.get(f'{api_url}/breachedaccount/{email}', headers=headers)

# Check the status code of the response
if response.status_code == 404:
    print("Email not found in data breaches")
elif response.status_code != 200:
    print("Error checking email")
else:
    # Extract the name of the breaches from the response
    breaches = [breach['Name'] for breach in response.json()]
    print(f"Email found in following breaches: {', '.join(breaches)}.")

# Hash the password before sending it to the HIBP API
password = input("Enter your password: ")
hashed_password = hashlib.sha1(password.encode('utf-8')).hexdigest().upper()
prefix = hashed_password[:5]
suffix = hashed_password[5:]

# Send the GET request to the HIBP API
response = requests.get(f'{pwd_api_url}/{prefix}', headers=headers)

# Check the status code of the response
if response.status_code != 200:
    print("Error checking password")
else:
    # Check if the hashed password suffix exists in the response
    for line in response.text.splitlines():
        line_suffix, count = line.split(':')
        if line_suffix == suffix:
            print(f"Password found {count} times. Please use a different password.")
            break
    else:
        print(f"Password not found. You can use this password.")

# Make the GET request
response = requests.get(f'{api_url}/breaches', headers=headers)

# Print the status code of the response
print(response.status_code)

# Print the response content (a list of breach objects)
# print(response.json())

# Display the breaches
breaches = json.loads(response.text)
count = len(breaches)
for breach in breaches:
    print(f'Name: {breach["Name"]}')
    print(f'Title: {breach["Title"]}')
    print(f'Domain: {breach["Domain"]}')
    print(f'Breach date: {breach["BreachDate"]}')
    print('---')
print(f'Total number of breaches: {count}')
