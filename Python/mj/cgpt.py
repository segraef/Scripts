import os, openai, random, csv
from dotenv import load_dotenv

# Load the environment variables from .env
load_dotenv()

# Get the API key from the environment variables
API_KEY = os.getenv('CGPT_API_KEY')

print("OpenAI CGPT API key loaded.")

# Function to generate prompts based on tags
def generate_prompts(tags, num_prompts):
    prompts = []

    for _ in range(num_prompts):
        # Generate a random prompt based on tags
        prompt = f"Generate a story with the tags: {', '.join(tags)}"
        response = openai.Completion.create(
            engine="text-davinci-002",
            prompt=prompt,
            max_tokens=150,
            n=1,
        )
        generated_prompt = response.choices[0].text.strip()

        # Append the generated prompt to the list
        prompts.append({"prompt": generated_prompt, "tags": ", ".join(tags)})

    return prompts

# Function to write prompts to a CSV file
def write_to_csv(prompts, filename):
    with open(filename, mode='w', newline='') as file:
        writer = csv.DictWriter(file, fieldnames=["prompt", "tags"])
        writer.writeheader()
        writer.writerows(prompts)

# Example usage
if __name__ == "__main__":
    # Set your tags and number of prompts to generate
    input_tags = ["fantasy", "adventure"]
    num_prompts_to_generate = 5

    # Generate prompts
    generated_prompts = generate_prompts(input_tags, num_prompts_to_generate)

    # Write prompts to CSV file
    output_csv_filename = "generated_prompts.csv"
    write_to_csv(generated_prompts, output_csv_filename)

    print(f"Generated prompts written to {output_csv_filename}")
