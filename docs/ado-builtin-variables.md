# Azure Pipelines built-in variables

Reference notes for inspecting the built-in variables Azure Pipelines exposes to
a job. This is documentation, not a runnable PowerShell script.

## Dump every variable from a job

Run an inline Bash step that prints the environment, sorted:

```bash
env | sort
```

## Equivalent inline step in `azure-pipelines.yml`

The `steps` section is used inside a `job` section:

```yaml
steps: # 'Steps' section is to be used inside 'job' section.
  - task: Bash@3
    inputs:
      targetType: 'inline'
      script: 'env | sort'
```

## Reference

Microsoft Learn: Define variables / built-in (predefined) variables for Azure
Pipelines.

<https://learn.microsoft.com/azure/devops/pipelines/build/variables?view=azure-devops&tabs=yaml>
