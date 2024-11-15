#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# -------------------------------
# Configuration
# -------------------------------

# Default values
BRANCH="develop"
NUM_MERGES=10
OUTPUT_FILE="RELEASE_NOTES.md"

# LLM Configuration
LLM_MODEL="claude-3.5-sonnet"  # Specify the LLM model to use
LLM_COMMAND="llm"              # Command to invoke the LLM

# -------------------------------
# Function to display usage information
# -------------------------------
usage() {
    echo "Usage: $0 [-b branch] [-n number_of_merges] [-o output_file]"
    echo "  -b, --branch           The target branch to generate release notes for (default: main)"
    echo "  -n, --number           The number of last merge commits to include (default: 10)"
    echo "  -o, --output           The output file for release notes (default: RELEASE_NOTES.md)"
    echo "  -h, --help             Display this help message"
    exit 1
}

# -------------------------------
# Parse command-line arguments
# -------------------------------
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -b|--branch)
            BRANCH="$2"
            shift
            ;;
        -n|--number)
            if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                echo "Error: Number of merges must be a positive integer."
                usage
            fi
            NUM_MERGES="$2"
            shift
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*|--*)
            echo "Unknown option $1"
            usage
            ;;
        *)
            echo "Unknown argument $1"
            usage
            ;;
    esac
    shift
done

# -------------------------------
# Verify LLM Command Exists
# -------------------------------
if ! command -v "$LLM_COMMAND" &> /dev/null; then
    echo "Error: LLM command '$LLM_COMMAND' not found. Please ensure it is installed and in your PATH."
    exit 1
fi

# -------------------------------
# Fetch the latest commits
# -------------------------------
echo "Fetching the latest commits from branch '$BRANCH'..."
git fetch origin "$BRANCH"

# Check if the branch exists
if ! git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    echo "Error: Branch '$BRANCH' does not exist."
    exit 1
fi

# -------------------------------
# Get the last N merge commits
# -------------------------------
echo "Retrieving the last $NUM_MERGES merge commits from branch '$BRANCH'..."
MERGE_COMMITS=$(git log "$BRANCH" --merges -n "$NUM_MERGES" --pretty=format:"- %s")

# Check if there are any merge commits
if [ -z "$MERGE_COMMITS" ]; then
    echo "No merge commits found on branch '$BRANCH'."
    exit 0
fi

# -------------------------------
# Prepare the prompt for the LLM
# -------------------------------
PROMPT="Generate a well-formatted release notes document based on the following Git merge commit messages. Categorize the changes into Features, Bug Fixes, and Improvements if applicable. Use Markdown formatting.

### Commit Messages:
$MERGE_COMMITS

### Release Notes:
"

# -------------------------------
# Call the LLM
# -------------------------------
echo "Sending commit messages to the LLM for processing..."

# Invoke the LLM with the specified model and prompt
RELEASE_NOTES=$("$LLM_COMMAND" -m "$LLM_MODEL" "$PROMPT")

# -------------------------------
# Validate LLM Response
# -------------------------------
if [ -z "$RELEASE_NOTES" ] || [ "$RELEASE_NOTES" == "null" ]; then
    echo "Error: Failed to retrieve release notes from the LLM."
    exit 1
fi

# -------------------------------
# Write the release notes to the output file
# -------------------------------
echo "Writing release notes to '$OUTPUT_FILE'..."
echo "$RELEASE_NOTES" > "$OUTPUT_FILE"

echo "Release notes have been successfully generated in '$OUTPUT_FILE'."
