#!/usr/bin/env bash
# Runs Exercise 14 end to end on your Mac.
# Usage: ./run_all.sh https://github.com/<your-username>/genre_classification.git
set -euo pipefail
cd "$(dirname "$0")"

REPO_URL="${1:-}"
if [ -z "$REPO_URL" ]; then
  echo "Pass your repo URL, e.g. ./run_all.sh https://github.com/you/genre_classification.git"
  exit 1
fi

# 1. conda check
if ! command -v conda >/dev/null 2>&1; then
  echo "conda not found. Install Miniconda first: https://docs.conda.io/en/latest/miniconda.html"
  exit 1
fi
eval "$(conda shell.bash hook)"

# 2. A small env with mlflow + hydra + wandb to launch the pipeline
if ! conda env list | grep -q "^ex14_sol "; then
  echo ">> Creating the ex14_sol conda env (one time, a few minutes)"
  conda env create -f conda.yml
fi
conda activate ex14_sol

# 3. W&B login check
if ! grep -q "api.wandb.ai" ~/.netrc 2>/dev/null && [ -z "${WANDB_API_KEY:-}" ]; then
  echo ">> You're not logged in to W&B. Paste your key from https://wandb.ai/authorize"
  wandb login
fi

# 4. Starter kit commit + push
if [ ! -d .git ]; then
  git init -q
  git branch -M main
  git remote add origin "$REPO_URL"
fi
git add .
git commit -qm "Starter kit with completed main.py" || true
git push -u origin main

# 5. Dev run (exercise_14)
sed -i '' 's/^  project_name: .*/  project_name: exercise_14/' config.yaml
echo ">> Dev run (exercise_14). First run builds the step envs, so expect 10-20 min."
mlflow run .

# 6. Production run (genre_classification_prod)
sed -i '' 's/^  project_name: .*/  project_name: genre_classification_prod/' config.yaml
echo ">> Production run (genre_classification_prod)"
mlflow run .

# 7. Tag the newest model export as prod
python - <<'PY'
import wandb
api = wandb.Api()
art = api.artifact(f"{api.default_entity}/genre_classification_prod/model_export:latest")
if "prod" not in art.aliases:
    art.aliases.append("prod")
    art.save()
print(f">> Tagged {art.name} as prod")
PY

# 8. Final push
git add .
git commit -qm "Production run config" || true
git push
echo ">> Done."
