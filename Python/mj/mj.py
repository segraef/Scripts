# Help me write a python script to automate midjourney.
# create a variable called prompts_file with the value "prompts.txt"
# create a variable called processed_prompts_file with the value "processed_prompts.txt"
# read all the lines in the prompts_file and store them in a variable called prompts
# loop through each prompt • in prompts
# create a variable called mj_prompt with the value "/imagine prompt: " + prompt
# print mj_prompt to the console
#
# write mj_prompt to the clipboard
# pause for 2 seconds

import time
import pyperclip

# Define file names
prompts_file = "prompts.txt"
processed_prompts_file = "processed_prompts.txt"

# Read prompts from the file
with open(prompts_file, "r") as file:
    prompts = file.readlines()

# Loop through each prompt
for prompt in prompts:
    # Process the prompt
    mj_prompt = "/imagine prompt: " + prompt.strip()

    # Print the processed prompt to the console
    print(mj_prompt)

    # Write the processed prompt to the clipboard
    pyperclip.copy(mj_prompt)

    # Append the processed prompt to the processed prompts file
    with open(processed_prompts_file, "a") as file:
        file.write(mj_prompt + "\n")

    # Pause for 2 seconds
    time.sleep(2)

print("Midjourney automation completed.")
