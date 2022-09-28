# this is inline code
env | sort

# code trimmed for brevity from azure-pipelines.yml

  steps: # 'Steps' section is to be used inside 'job' section.
  – task: Bash@3
    inputs:
      targetType: 'inline'
      script: 'env | sort'


https://docs.microsoft.com/en-us/azure/devops/pipelines/build/variables?view=azure-devops&tabs=yaml