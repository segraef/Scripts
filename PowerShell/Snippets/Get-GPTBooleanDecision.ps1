
<#
.SYNOPSIS
    Makes a boolean decision using OpenAI's GPT model.

.DESCRIPTION
    This function sends a question to OpenAI's GPT model and returns a boolean value based on the model's response.
    The function is designed to simplify decision making by converting natural language questions into true/false answers.

.PARAMETER Question
    The question to ask the GPT model. The question should be formulated to yield a true or false response.

.INPUTS
    System.String

.OUTPUTS
    System.Boolean
    Returns $true if the model responds with "True", $false if it responds with "False",
    and $null if there's an error or unexpected response.

.EXAMPLE
    PS> Get-GPTBooleanDecision -Question "Is it a good practice to use comments in code?"
    True

.EXAMPLE
    PS> Get-GPTBooleanDecision -Question "Should I delete my production database without a backup?"
    False

.NOTES
    Version:        1.0
    Author:         Sebastian Graef
    Creation Date:  27-05-2025
    Requires:       OpenAI API key set as $env:OPENAI_API_KEY environment variable

.LINK
    https://platform.openai.com/docs/api-reference/chat
#>
function Get-GPTBooleanDecision {
  param (
    [Parameter(Mandatory = $true)]
    [string]$Question
  )

  $apiKey = $env:OPENAI_API_KEY  # Set this in your environment
  $uri = "https://api.openai.com/v1/chat/completions"

  $headers = @{
    "Authorization" = "Bearer $apiKey"
    "Content-Type"  = "application/json"
  }

  $prompt = @"
You are a decision function that only answers with "True" or "False".

Question: $Question

Only respond with either "True" or "False", and nothing else.
"@

  $body = @{
    model       = "gpt-3.5-turbo"
    messages    = @(
      @{ role = "system"; content = "You are a Boolean decision assistant." },
      @{ role = "user"; content = $prompt }
    )
    temperature = 0
  } | ConvertTo-Json -Depth 3

  try {
    $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body
    $reply = $response.choices[0].message.content.Trim()

    if ($reply -eq "True") {
      return $true
    } elseif ($reply -eq "False") {
      return $false
    } else {
      Write-Warning "Unexpected response: $reply"
      return $null
    }
  } catch {
    Write-Error "Error querying LLM: $_"
    return $null
  }
}
