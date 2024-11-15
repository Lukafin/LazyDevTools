#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# -------------------------------
# Configuration
# -------------------------------

# Default values
BRANCH="develop"
METHOD=""
START_TAG=""
END_TAG=""
START_DATE=""
END_DATE=""
OUTPUT_FILE="RELEASE_NOTES.md"

# LLM Configuration
LLM_MODEL="claude-3.5-sonnet"  # Specify the LLM model to use
LLM_COMMAND="llm"              # Command to invoke the LLM

# -------------------------------
# Function to display usage information
# -------------------------------
usage() {
    echo "Usage: $0 -m METHOD [OPTIONS]"

    echo ""
    echo "Generate release notes based on Git merge commits using either tag-based or date-based selection."
    echo ""
    echo "Methods:"
    echo "  -m, --method METHOD       Selection method: 'tag' or 'date' (required)"
    echo ""
    echo "Tag-Based Options (use with -m tag):"
    echo "  -s, --start_tag TAG       Starting Git tag to compare against (optional; defaults to latest tag)"
    echo "  -T, --end_tag TAG         Ending Git tag to compare up to (optional; defaults to HEAD)"
    echo ""
    echo "Date-Based Options (use with -m date):"
    echo "  -d, --start_date DATE     Start date (e.g., '2023-01-01')"
    echo "  -e, --end_date DATE       End date (e.g., '2023-12-31')"
    echo ""
    echo "Common Options:"
    echo "  -b, --branch BRANCH       Target branch (default: main)"
    echo "  -o, --output FILE         Output file for release notes (default: RELEASE_NOTES.md)"
    echo "  -h, --help                Display this help message"
    echo ""
    echo "Examples:"
    echo "  # Tag-Based (latest tag to HEAD)"
    echo "  $0 -m tag -b main -o RELEASE_NOTES.md"
    echo ""
    echo "  # Tag-Based (specific start and end tags)"
    echo "  $0 -m tag -s v1.0.0 -T v2.0.0 -b develop -o DEV_RELEASE_NOTES.md"
    echo ""
    echo "  # Date-Based"
    echo "  $0 -m date -d '2023-01-01' -e '2023-12-31' -b main -o RELEASE_NOTES_2023.md"
    exit 1
}

# -------------------------------
# Parse command-line arguments
# -------------------------------
if [[ "$#" -eq 0 ]]; then
    usage
fi

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -m|--method)
            METHOD="$2"
            shift
            ;;
        -s|--start_tag)
            START_TAG="$2"
            shift
            ;;
        -T|--end_tag)
            END_TAG="$2"
            shift
            ;;
        -d|--start_date)
            START_DATE="$2"
            shift
            ;;
        -e|--end_date)
            END_DATE="$2"
            shift
            ;;
        -b|--branch)
            BRANCH="$2"
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
# Validate Method and Options
# -------------------------------
if [[ -z "$METHOD" ]]; then
    echo "Error: Selection method is required."
    usage
fi

if [[ "$METHOD" != "tag" && "$METHOD" != "date" ]]; then
    echo "Error: Invalid method '$METHOD'. Choose 'tag' or 'date'."
    usage
fi

# Validate mutually exclusive options
if [[ "$METHOD" == "tag" ]]; then
    if [[ -n "$START_DATE" || -n "$END_DATE" ]]; then
        echo "Error: Start date and end date options are only valid with 'date' method."
        usage
    fi
elif [[ "$METHOD" == "date" ]]; then
    if [[ -n "$START_TAG" || -n "$END_TAG" ]]; then
        echo "Error: Tag options are only valid with 'tag' method."
        usage
    fi

    if [[ -z "$START_DATE" && -z "$END_DATE" ]]; then
        echo "Error: At least one of start date or end date must be specified for 'date' method."
        usage
    fi
fi

# -------------------------------
# Verify LLM Command Exists
# -------------------------------
if ! command -v "$LLM_COMMAND" &> /dev/null; then
    echo "Error: LLM command '$LLM_COMMAND' not found. Please ensure it is installed and in your PATH."
    exit 1
fi

# -------------------------------
# Fetch the latest commits and tags
# -------------------------------
echo "Fetching the latest commits and tags from branch '$BRANCH'..."
git fetch origin "$BRANCH" --tags

# Check if the branch exists
if ! git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    echo "Error: Branch '$BRANCH' does not exist."
    exit 1
fi

# -------------------------------
# Determine the Reference Points and Get Merge Commits
# -------------------------------
MERGE_COMMITS=""

if [[ "$METHOD" == "tag" ]]; then
    # Handle end_tag
    if [[ -n "$END_TAG" ]]; then
        echo "Using specified end tag '$END_TAG'."
        # Validate end_tag
        if ! git rev-parse "$END_TAG"^{tag} >/dev/null 2>&1; then
            echo "Error: End tag '$END_TAG' does not exist."
            exit 1
        fi
    else
        echo "Determining the latest tag on branch '$BRANCH'..."
        LATEST_TAG=$(git describe --tags --abbrev=0 "$BRANCH" 2>/dev/null || true)
        if [[ -z "$LATEST_TAG" ]]; then
            echo "No tags found on branch '$BRANCH'. Using the initial commit as the end reference."
            END_TAG=$(git rev-list --max-parents=0 origin/"$BRANCH")
        else
            echo "Latest tag on branch '$BRANCH' is '$LATEST_TAG'."
            END_TAG="$LATEST_TAG"
        fi
    fi

    # Handle start_tag
    if [[ -n "$START_TAG" ]]; then
        echo "Using specified start tag '$START_TAG' as the reference."
        # Validate start_tag
        if ! git rev-parse "$START_TAG"^{tag} >/dev/null 2>&1; then
            echo "Error: Start tag '$START_TAG' does not exist."
            exit 1
        fi
        REFERENCE_COMMIT="$START_TAG"
    else
        # Determine the previous tag before end_tag
        echo "Determining the previous tag before '$END_TAG'..."
        PREV_TAG=$(git describe --tags --abbrev=0 "$END_TAG"^ 2>/dev/null || true)
        if [[ -z "$PREV_TAG" ]]; then
            echo "No previous tags found before '$END_TAG'. Using the initial commit as the reference."
            REFERENCE_COMMIT=$(git rev-list --max-parents=0 origin/"$BRANCH")
        else
            echo "Previous tag is '$PREV_TAG'."
            REFERENCE_COMMIT="$PREV_TAG"
        fi
    fi

    echo "Retrieving merge commits on branch '$BRANCH' from '$REFERENCE_COMMIT' to '$END_TAG'..."
    MERGE_COMMITS=$(git log "$REFERENCE_COMMIT".."$END_TAG" --merges --pretty=format:"- %s")

elif [[ "$METHOD" == "date" ]]; then
    echo "Retrieving merge commits on branch '$BRANCH' based on date range..."

    if [[ -n "$START_DATE" && -n "$END_DATE" ]]; then
        echo "From '$START_DATE' to '$END_DATE'."
        MERGE_COMMITS=$(git log origin/"$BRANCH" --merges --since="$START_DATE" --until="$END_DATE" --pretty=format:"- %s")
    elif [[ -n "$START_DATE" ]]; then
        echo "Since '$START_DATE'."
        MERGE_COMMITS=$(git log origin/"$BRANCH" --merges --since="$START_DATE" --pretty=format:"- %s")
    elif [[ -n "$END_DATE" ]]; then
        echo "Up to '$END_DATE'."
        MERGE_COMMITS=$(git log origin/"$BRANCH" --merges --until="$END_DATE" --pretty=format:"- %s")
    fi
fi

# Check if there are any merge commits
if [[ -z "$MERGE_COMMITS" ]]; then
    echo "No merge commits found on branch '$BRANCH' with the specified criteria."
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
if [[ -z "$RELEASE_NOTES" || "$RELEASE_NOTES" == "null" ]]; then
    echo "Error: Failed to retrieve release notes from the LLM."
    exit 1
fi

# -------------------------------
# Write the release notes to the output file
# -------------------------------
echo "Writing release notes to '$OUTPUT_FILE'..."
echo "$RELEASE_NOTES" > "$OUTPUT_FILE"

echo "Release notes have been successfully generated in '$OUTPUT_FILE'."
