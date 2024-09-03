# Start Generation Here
#!/bin/bash

#if you want to get summary of last 14 days of commits call this script like: ./codingSummary.sh 14 
#you need tools https://github.com/simonw/llm and https://github.com/simonw/llm-claude-3

# Check if a parameter is provided, otherwise default to 7 days
days_ago=${1:-7}

# Get the git commit messages from the last $days_ago days
commit_messages=$(git log --since="$days_ago days ago" --pretty=format:"%s")

# Check if there are any commit messages
if [ -z "$commit_messages" ]; then
  echo "No commits in the last $days_ago days."
  exit 0
fi

# Summarize the commit messages using the llm tool
summary=$(llm -m claude-3.5-sonnet "Summarize the following git commit messages from the last $days_ago days: $commit_messages. Include branch names next to summary bullet points.")

# Print the summary
echo "Summary of git commits from the last $days_ago days:"
echo "$summary"
# End Generation Here
