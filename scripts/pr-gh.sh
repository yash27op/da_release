#!/bin/bash
set -e

# === Load .env ===
if [ -f ".env" ]; then
  source .env
else
  echo " .env file not found."
  #exit 1
fi

GH_TOKEN=$1
# === Check Token ===
if [[ -z "$GH_TOKEN" ]]; then
  echo " GH_TOKEN is not set. Make sure .env exists with GH_TOKEN=yourtoken"
  exit 1
fi

# === Debug Print (to verify) ===
echo " GH_TOKEN is loaded: ${GH_TOKEN:0:5}********"


#################################  ===  INPUT VARIABLES === ##################################

NEW_BRANCH="collaborate"
BASE_BRANCH="main"
COMMIT_MESSAGE="Multiple Colllaborators are added"
PR_TITLE="Assigning new Collaborator"
PR_BODY="Added enhancements to the documentation section."
REVIEWERS="Vipin654"  # Comma-separated GitHub usernames
GH_TOKEN="${GH_TOKEN}"  # Provided externally or via .env file

################################## === FUNCTION: PR Workflow === ##################################

create_pr_workflow() {
  # === Authenticate GitHub CLI ===
  if ! gh auth status &>/dev/null; then
    if [[ -z "$GH_TOKEN" ]]; then
      echo " GH_TOKEN is not set. Export it or define in a .env file."
      exit 1
    fi
    echo "Authenticating GitHub CLI via token..."
    echo "$GH_TOKEN" | gh auth login --with-token > /dev/null
    echo " Authenticated."
  else
    echo " GitHub CLI already authenticated."
  fi

  # === Create and Switch Branch ===
  git checkout -b "$NEW_BRANCH"
  echo " Switched to new branch: $NEW_BRANCH"

  # === Add, Commit, and Push Changes ===
  git add .
  git status
  git commit -m "$COMMIT_MESSAGE"
  echo "showing git diff"
  git diff
  echo "shown"
  git push -u origin "$NEW_BRANCH"
  echo " Changes committed and pushed."

  # === Create PR ===
  if [[ -z "$REVIEWERS" ]]; then
    gh pr create --base "$BASE_BRANCH" --head "$NEW_BRANCH" --title "$PR_TITLE" --body "$PR_BODY"
  else
    gh pr create --base "$BASE_BRANCH" --head "$NEW_BRANCH" --title "$PR_TITLE" --body "$PR_BODY" --reviewer "$REVIEWERS"
  fi

  # === PR Status ===
  if [ $? -eq 0 ]; then
    echo " Pull request successfully created from $NEW_BRANCH to $BASE_BRANCH."
  else
    echo "Failed to create pull request."
  fi
}


################################## === RUN SCRIPT ============== ##################################

create_pr_workflow
