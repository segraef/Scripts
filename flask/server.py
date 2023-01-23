import os,requests,hashlib
from flask import Flask, render_template, request
from dotenv import load_dotenv

app = Flask(__name__)

# Load the environment variables from .env
load_dotenv()

# Get the API key from the environment variables
API_KEY = os.getenv('HIBP_API_KEY')


@app.route('/')
def index():
    return render_template('index.html')

@app.route('/cheat')
def cheat():
    return render_template('cheat.html')


@app.route('/test/')
def test():
    print(f'I got clicked and here is your API key: {API_KEY}')
    return 'Click. Here is your API key: ' + API_KEY


@app.route('/check', methods=['POST'])
def check():
    email = request.form.get('email')
    password = request.form.get('password2')
    result = {}
    if not email and not password:
        return "No email or password provided", 400
    if email:
        # Send the email to the HIBP API
        headers = {'hibp-api-key': API_KEY}
        response = requests.get(
            f'https://haveibeenpwned.com/api/v3/breachedaccount/{email}', headers=headers)
        if response.status_code == 404:
            result["email"] = "Email not found in data breaches"
        elif response.status_code != 200:
            result["email"] = "Error checking email"
        else:
            # Extract the name of the breaches from the response
            breaches = [breach['Name'] for breach in response.json()]
            result["email"] = f"Email found in following breaches: {', '.join(breaches)}."
            # foreach breach in breache --> GET https://haveibeenpwned.com/api/v3/breaches/{breach}
    if password:
        # Hash the password before sending it to the HIBP API
        hashed_password = hashlib.sha1(
            password.encode('utf-8')).hexdigest().upper()
        prefix = hashed_password[:5]
        suffix = hashed_password[5:]

        # Send the hashed password to the HIBP API
        headers = {'hibp-api-key': API_KEY}
        response = requests.get(
            f'https://api.pwnedpasswords.com/range/{prefix}', headers=headers)
        if response.status_code != 200:
            result["password"] = "Error checking password"
        else:
            # Check if the hashed password suffix exists in the response
            for line in response.text.splitlines():
                line_suffix, count = line.split(':')
                if line_suffix == suffix:
                    result["password"] = f"Password found {count} times. Please use a different password."
                    break
            else:
                result["password"] = "Password not found. You can use this password."
    return render_template("result.html", result=result)


if __name__ == '__main__':
    app.run(port=5001, debug=True)
