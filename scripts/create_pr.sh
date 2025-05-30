#!/bin/bash
set -e


# ============ GLOBAL VARIABLES ============                                                                                                                                     

REPO_URL="https://github.com/repo-name" # Set this to the target repo URL
REPO_DIR=" "                                      # Local directory name after cloning
NEW_BRANCH="branch_name"
BASE_BRANCH="main"
PR_TITLE="Title of the PR"
PR_BODY="Description of the Pull Request"
REVIEWERS="Reviewer username" # Leave blank "" if no reviewer ,if yes he shoukd be a collaborator
COMMIT_MSG="This will be a commit message"



# ============  CHECK DEPENDENCY ============ 

check_dependencies() {
    if ! command -v gh &>/dev/null; then
        echo "GitHub CLI (gh) is not installed. Install it from https://cli.github.com/"
        exit 1
    fi
    if ! command -v git &>/dev/null; then
        echo "Git is not installed."
        exit 1
    fi
}


# ============  GIT CLONE ============                                                                                                                                       

cloning_repo() {
    if [ ! -d "$REPO_DIR/.git" ]; then
        git clone "$REPO_URL" "$REPO_DIR"
    fi
    cd "$REPO_DIR"
    echo " Moved into repository directory: $REPO_DIR"
}


# ============  CREATE NEW BRANCH ================                                                                                                                                     #

create_branch() {
    git checkout -b "$NEW_BRANCH"
    echo " Created and switched to branch: $NEW_BRANCH"

}
# ===============  PROMPT FOR CHANGES OR AUTO-ADD ONE ===============  

prompt_changes() {
    echo " Make your changes now in '$REPO_DIR'. Press Enter when done."
    read -p "Press Enter to continue..."
    git status

    if [[ -z $(git status --porcelain) ]]; then
        echo "# Auto-generated PR test change on $(date)" >> README.md
        echo "🛠️  No user changes found. Dummy line added to README.md."
    fi
}


# ========================  COMMIT THE CHANGES ========================                                                                                                                                        

commit_changes() {
    if [[ -n $(git status --porcelain) ]]; then
        git add .
        git commit -m "$COMMIT_MSG"
        echo "Changes committed: $COMMIT_MSG"
    else
        echo "Still no changes to commit."
    fi
}


# ========================   PUSH BRANCH ========================                                                                                                                                      

push_changes_into_branch() {
    git push -u origin "$NEW_BRANCH"
}


# ======================== CREATE PR ========================                                                                                                                                  

create_pull_request() {
    echo "Attempting to create PR from '$NEW_BRANCH' to '$BASE_BRANCH' in repo: $REPO_URL"
    echo "Title: $PR_TITLE"
    echo "Body: $PR_BODY"
    echo "Reviewer(s): $REVIEWERS"

    if [[ -z "$REVIEWERS" ]]; then
        gh pr create --repo "$REPO_URL" --base "$BASE_BRANCH" --head "$NEW_BRANCH" --title "$PR_TITLE" --body "$PR_BODY"
    else
        gh pr create --repo "$REPO_URL" --base "$BASE_BRANCH" --head "$NEW_BRANCH" --title "$PR_TITLE" --body "$PR_BODY" --reviewer "$REVIEWERS"
    fi

    PR_EXIT_CODE=$?
    if [ $PR_EXIT_CODE -eq 0 ]; then
        echo "Pull request created successfully."
    else
        echo "gh pr create failed with exit code $PR_EXIT_CODE"
        exit 1
    fi
}

# ======================== MAIN EXECUTION SCRIPT WORKFLOW ========================                                                                                                                                      #

main() {
    check_dependencies
    cloning_repo
    create_branch
    prompt_changes
    commit_changes
    push_changes_into_branch
    create_pull_request
}

main
