#!/bin/bash

#if PR for merging branch bugfix/date-formatting-locale into develop is opened call this script by: ./prSummary.sh bugfix/date-formatting-locale  
#you need tools https://github.com/simonw/llm and https://github.com/simonw/llm-claude-3

# Check if a branch name is provided
if [ $# -eq 0 ]; then
    echo "Error: Please provide a branch name as an argument."
    echo "Usage: $0 <BRANCH_NAME>"
    exit 1
fi

BRANCH_NAME=$1


#git fetch --all
#git branch -r
# Fetch the latest changes from the remote repository
git fetch origin


# Fetch the git diff between the specified branch and develop
BRANCH_DIFF=$(git diff origin/develop..origin/$BRANCH_NAME 2>/dev/null || echo "Error: Unable to find the specified branch.")

# Check if the diff is empty
if [ -z "$BRANCH_DIFF" ]; then
    echo "Error: No diff found for branch '$BRANCH_NAME'"
    exit 1
fi

# Prepare the input for the LLM
LLM_INPUT="Summarize the following git diff for branch '$BRANCH_NAME':

$BRANCH_DIFF

Please provide a concise summary of the changes, including:
1. Files modified
2. Key additions or removals
3. Potential impact on the codebase
4. bad coding practices (security, architecture, modularity)"

# Generate summary using LLM
SUMMARY=$(llm -m claude-3.5-sonnet "$LLM_INPUT")

# Print the summary
echo "Summary of branch '$BRANCH_NAME' based on git diff:"
echo "$SUMMARY"
