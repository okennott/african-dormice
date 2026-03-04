# config — Configuration Files

Project-level configuration for local paths and directory structure. These files allow the analysis scripts to be portable across different machines without modifying the scripts themselves.

## Files

| File | Description |
|---|---|
| `paths.yaml.example` | Template for local path configuration — **copy this to `paths.yaml` and edit** |
| `paths.yaml` | Your local configuration (gitignored — never committed) |
| `directory_structure.yaml` | Canonical definition of all 50+ project directories |

## Setup

```bash
# Copy the example template
cp config/paths.yaml.example config/paths.yaml

# Edit with your local paths
nano config/paths.yaml   # or open in your editor
```

## `paths.yaml` Structure

```yaml
data_root:
  local: "/path/to/your/Graphiurus/analysis/directory"

external_tools:
  iqtree: "iqtree2"          # command name if on PATH, or full path
  astral: "/path/to/astral.5.7.8.jar"
  paml_dir: ""               # path to PAML installation (optional)
  mrbayes: "mb"
  beast: "beast"
  amas: "AMAS.py"

compute:
  default_threads: 8
  max_memory_gb: 16
```

## `directory_structure.yaml`

Defines the canonical layout of all analysis, data, visualization, and output directories for the project. This file is used by the setup script (`setup_directories.ps1` on Windows or equivalent shell script) to create the full directory tree on a new machine.

It also serves as living documentation: each entry includes a `description` field explaining what the directory contains and whether its contents are gitignored.

## Important

`config/paths.yaml` is listed in `.gitignore` and **must never be committed** — it contains absolute paths specific to your local filesystem. Only `paths.yaml.example` (with placeholder paths) is tracked in git.
