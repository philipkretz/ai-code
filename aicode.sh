#!/bin/bash

# AI Code Assistant Tool
# A Claude Code-like bash script that can create, edit, and manage files using AI assistance

set -euo pipefail

# Configuration
SCRIPT_NAME=$(basename "$0")
CONFIG_FILE="$HOME/.ai-code-config"
DEFAULT_MODEL="gpt-4"
DEFAULT_MAX_TOKENS=4000
DEFAULT_TEMPERATURE=0.1
WORKSPACE_DIR="$(pwd)"
SESSION_LOG="$WORKSPACE_DIR/.ai-session.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Help function
show_help() {
    cat << 'EOF'
Usage: $SCRIPT_NAME [OPTIONS] [COMMAND] "Description of what you want to do"

An AI-powered code assistant that can create, edit, and manage files in your workspace.
If no command is specified, starts in interactive mode.

COMMANDS:
    create                  Create new files or projects
    edit                    Edit existing files
    analyze                 Analyze code or project structure
    refactor                Refactor existing code
    test                    Generate or run tests
    debug                   Help debug issues
    explain                 Explain code or concepts
    interactive             Start interactive mode (default if no args)

OPTIONS:
    -h, --help              Show this help message
    -c, --config FILE       Use custom config file
    -e, --endpoint URL      API endpoint URL
    -k, --key KEY           API key
    -m, --model MODEL       Model to use (default: gpt-4)
    -t, --temperature NUM   Temperature (0.0-2.0, default: 0.1)
    -T, --max-tokens NUM    Maximum tokens (default: 4000)
    -f, --files FILES       Specific files to work with (comma-separated)
    -d, --directory DIR     Target directory (default: current)
    -w, --workspace         Show workspace overview
    -l, --language LANG     Programming language hint
    -v, --verbose           Verbose output
    -y, --yes               Auto-confirm file operations
    --dry-run               Show what would be done without executing
    --backup                Create backups before editing
    --setup                 Interactive setup

EXAMPLES:
    $SCRIPT_NAME                                    # Start interactive mode
    $SCRIPT_NAME create "A Python web scraper for news articles"
    $SCRIPT_NAME edit -f main.py "Add error handling to the login function"
    $SCRIPT_NAME refactor -f "*.js" "Convert to ES6 modules"
    $SCRIPT_NAME test "Generate unit tests for the user authentication"
    $SCRIPT_NAME analyze "Review the project structure and suggest improvements"
    $SCRIPT_NAME "How does this authentication work?"  # Defaults to explain

CONFIGURATION:
    The tool looks for configuration in ~/.ai-code-config
    API key can be set via COPILOT_KEY environment variable (recommended)
    
    Example:
        export COPILOT_KEY="your-api-key-here"
        ./aicode.sh create "A Python web scraper"
EOF
}

# Logging functions
log_info() {
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        echo -e "${BLUE}[INFO]${NC} $1" >&2
    fi
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >> "$SESSION_LOG" 2>/dev/null || true
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] $1" >> "$SESSION_LOG" 2>/dev/null || true
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >> "$SESSION_LOG" 2>/dev/null || true
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $1" >> "$SESSION_LOG" 2>/dev/null || true
}

log_action() {
    echo -e "${MAGENTA}[ACTION]${NC} $1" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ACTION] $1" >> "$SESSION_LOG" 2>/dev/null || true
}

# Load configuration
load_config() {
    local config_file="${1:-$CONFIG_FILE}"
    
    if [[ -f "$config_file" ]]; then
        log_info "Loading configuration from $config_file"
        # shellcheck source=/dev/null
        source "$config_file"
    fi
    
    # Use COPILOT_KEY environment variable if available
    if [[ -n "${COPILOT_KEY:-}" ]]; then
        API_KEY="$COPILOT_KEY"
        log_info "Using API key from COPILOT_KEY environment variable"
    fi
}

# Interactive setup
setup_config() {
    echo "Setting up AI Code Assistant configuration..."
    echo
    
    read -p "API Endpoint URL: " -r api_endpoint
    
    # Check if COPILOT_KEY is already set
    if [[ -n "${COPILOT_KEY:-}" ]]; then
        echo "Using existing COPILOT_KEY environment variable for API key."
        api_key="$COPILOT_KEY"
    else
        read -p "API Key or set COPILOT_KEY environment variable: " -rs api_key
        echo
        echo "Note: You can also set the COPILOT_KEY environment variable instead of storing in config."
    fi
    
    read -p "Default Model [$DEFAULT_MODEL]: " -r model
    read -p "Default Temperature [$DEFAULT_TEMPERATURE]: " -r temperature
    read -p "Default Max Tokens [$DEFAULT_MAX_TOKENS]: " -r max_tokens
    
    model=${model:-$DEFAULT_MODEL}
    temperature=${temperature:-$DEFAULT_TEMPERATURE}
    max_tokens=${max_tokens:-$DEFAULT_MAX_TOKENS}
    
    # Write configuration
    cat > "$CONFIG_FILE" << EOF
# AI Code Assistant Configuration
API_ENDPOINT="$api_endpoint"
$(if [[ "$api_key" != "${COPILOT_KEY:-}" ]]; then echo "API_KEY=\"$api_key\""; else echo "# API_KEY is using COPILOT_KEY environment variable"; fi)
DEFAULT_MODEL="$model"
DEFAULT_TEMPERATURE="$temperature"
DEFAULT_MAX_TOKENS="$max_tokens"
EOF
    
    chmod 600 "$CONFIG_FILE"
    log_success "Configuration saved to $CONFIG_FILE"
    exit 0
}

# Check dependencies
check_dependencies() {
    local deps=("curl")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing[*]}"
        exit 1
    fi
}

# JSON escape function
json_escape() {
    local string="$1"
    # Escape backslashes, quotes, and newlines for JSON
    string="${string//\\/\\\\}"  # Escape backslashes
    string="${string//\"/\\\"}"  # Escape quotes
    string="${string//$'\n'/\\n}"  # Escape newlines
    string="${string//$'\r'/\\r}"  # Escape carriage returns
    string="${string//$'\t'/\\t}"  # Escape tabs
    echo "$string"
}

# Create JSON payload for LLM Forge API
create_json_payload() {
    local system_prompt="$1"
    local user_prompt="$2"
    local model="$3"
    local temperature="$4"
    local max_tokens="$5"
    
    # Escape JSON strings
    system_prompt=$(json_escape "$system_prompt")
    user_prompt=$(json_escape "$user_prompt")
    model=$(json_escape "$model")
    
    # LLM Forge requires specific format: role must be "user" or "bot", and needs "id" field
    # Combine system and user prompts since we can't use "system" role
    local combined_prompt="$system_prompt\n\n$user_prompt"
    combined_prompt=$(json_escape "$combined_prompt")
    
    cat << EOF
{
    "messages": [
        {
            "role": "user",
            "content": "$combined_prompt",
            "id": "$(date +%s)"
        }
    ],
    "temperature": $temperature,
    "max_tokens": $max_tokens
}
EOF
}

# Extract JSON field without jq
extract_json_field() {
    local json="$1"
    local field_path="$2"
    
    # Simple extraction for the specific case we need
    # This handles: .choices[0].message.content
    if [[ "$field_path" == "choices[0].message.content" ]]; then
        # Extract content field from first choice - handle escaped quotes and newlines
        echo "$json" | sed -n 's/.*"content"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' | tail -1 | sed 's/\\n/\n/g; s/\\"/"/g; s/\\\\/\\/g'
    elif [[ "$field_path" == "error.message" ]]; then
        # Extract error message
        echo "$json" | sed -n 's/.*"message"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
    elif [[ "$field_path" == "response" ]]; then
        # Try alternative response field for LLM Forge
        echo "$json" | sed -n 's/.*"response"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' | tail -1 | sed 's/\\n/\n/g; s/\\"/"/g; s/\\\\/\\/g'
    else
        echo "Field extraction failed" >&2
        return 1
    fi
}

# Get workspace context
get_workspace_context() {
    local target_dir="${1:-$WORKSPACE_DIR}"
    local context=""
    
    # Project structure
    context+="Project Structure:\n"
    if command -v tree >/dev/null 2>&1; then
        context+="$(tree -L 2 -I 'node_modules|.git|__pycache__|*.pyc' "$target_dir" 2>/dev/null || echo "Tree command failed")\n\n"
    else
        context+="$(find "$target_dir" -maxdepth 2 -type f -name "*.py" -o -name "*.js" -o -name "*.html" -o -name "*.css" -o -name "*.json" -o -name "*.md" 2>/dev/null | head -10)\n\n"
    fi
    
    # Git status if available
    if [[ -d "$target_dir/.git" ]]; then
        context+="Git Status:\n"
        context+="$(cd "$target_dir" && git status --porcelain 2>/dev/null || echo "No git changes")\n\n"
    fi
    
    echo -e "$context"
}

# Read file contents
read_file_contents() {
    local file_path="$1"
    local max_lines="${2:-50}"
    
    if [[ -f "$file_path" ]]; then
        echo "Contents of $file_path:"
        head -n "$max_lines" "$file_path"
        echo ""
    else
        echo "File $file_path does not exist."
    fi
}

# Show workspace overview
show_workspace() {
    echo -e "${CYAN}Workspace Overview:${NC}"
    echo "Working Directory: $WORKSPACE_DIR"
    echo
    get_workspace_context
}

# Create AI prompt based on command and context
create_ai_prompt() {
    local command="$1"
    local request="$2"
    local files="$3"
    local language="$4"
    local workspace_context="$5"
    
    local system_prompt=""
    local user_prompt=""
    
    case "$command" in
        "create")
            system_prompt="You are an expert software developer. Create high-quality, functional code files based on requirements. Always specify the exact filename and provide complete file content with proper comments."
            user_prompt="Create files for: $request"
            ;;
        "edit")
            system_prompt="You are an expert code editor. Analyze existing code and make precise improvements. Provide the complete updated file content and explain changes."
            user_prompt="Edit the following files: $request"
            ;;
        "analyze")
            system_prompt="You are a senior code reviewer. Analyze code structure, identify issues, and suggest improvements with focus on quality, security, and best practices."
            user_prompt="Analyze the code/project: $request"
            ;;
        "refactor")
            system_prompt="You are a refactoring expert. Improve code structure and maintainability while preserving functionality. Explain the changes and benefits."
            user_prompt="Refactor the code: $request"
            ;;
        "test")
            system_prompt="You are a testing expert. Create comprehensive test suites with good coverage. Generate both unit and integration tests as appropriate."
            user_prompt="Generate tests for: $request"
            ;;
        "debug")
            system_prompt="You are a debugging expert. Identify issues, trace problems, and provide solutions with clear explanations."
            user_prompt="Help debug this issue: $request"
            ;;
        "explain")
            system_prompt="You are a code educator. Explain code concepts, algorithms, and implementations clearly with examples."
            user_prompt="Explain: $request"
            ;;
        *)
            system_prompt="You are an AI coding assistant. Provide clear, actionable solutions for programming tasks."
            user_prompt="$request"
            ;;
    esac
    
    # Add context
    if [[ -n "$workspace_context" ]]; then
        user_prompt+="\n\nWorkspace Context:\n$workspace_context"
    fi
    
    if [[ -n "$files" ]]; then
        user_prompt+="\n\nTarget Files:\n"
        IFS=',' read -ra FILE_ARRAY <<< "$files"
        for file in "${FILE_ARRAY[@]}"; do
            if [[ -f "$file" ]]; then
                user_prompt+="\n$(read_file_contents "$file")"
            else
                user_prompt+="\nFile $file does not exist - will be created if needed."
            fi
        done
    fi
    
    if [[ -n "$language" ]]; then
        user_prompt+="\n\nProgramming language: $language"
    fi
    
    # Create JSON payload - LLM Forge uses standard OpenAI format
    create_json_payload "$system_prompt" "$user_prompt" "${MODEL:-$DEFAULT_MODEL}" "${TEMPERATURE:-$DEFAULT_TEMPERATURE}" "${MAX_TOKENS:-$DEFAULT_MAX_TOKENS}"
}

# Make API request
make_ai_request() {
    local endpoint="$1"
    local api_key="$2"
    local payload="$3"
    
    log_info "Making request to: $endpoint"
    log_info "Payload: $payload"
    
    local response
    response=$(curl -s -w "\n%{http_code}" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $api_key" \
        -d "$payload" \
        "$endpoint")
    
    local http_code
    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | head -n -1)
    
    log_info "HTTP Status: $http_code"
    log_info "Response body: $body"
    
    if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
        local content
        content=$(extract_json_field "$body" "choices[0].message.content")
        if [[ $? -eq 0 && -n "$content" ]]; then
            echo "$content"
        else
            # Try alternative extraction for different API formats
            local alt_content
            alt_content=$(echo "$body" | sed -n 's/.*"response"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' | head -1)
            if [[ -n "$alt_content" ]]; then
                echo "$alt_content" | sed 's/\\n/\n/g; s/\\"/"/g; s/\\\\/\\/g'
            else
                echo "No response found in API result"
                echo "Raw response: $body" >&2
            fi
        fi
    else
        log_error "HTTP $http_code: API request failed"
        echo "Full response: $body" >&2
        
        # Try to extract various error message formats
        local error_msg
        error_msg=$(extract_json_field "$body" "error.message" 2>/dev/null)
        if [[ $? -ne 0 || -z "$error_msg" ]]; then
            error_msg=$(echo "$body" | sed -n 's/.*"error"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
        fi
        if [[ $? -ne 0 || -z "$error_msg" ]]; then
            error_msg=$(echo "$body" | sed -n 's/.*"message"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
        fi
        
        if [[ -n "$error_msg" ]]; then
            echo "Error: $error_msg" >&2
        else
            echo "Unknown API error - check endpoint and API key" >&2
        fi
        return 1
    fi
}

# Extract file operations from AI response
extract_file_operations() {
    local ai_response="$1"
    local dry_run="$2"
    local auto_confirm="$3"
    local backup="$4"
    
    echo -e "${CYAN}AI Response:${NC}"
    echo "$ai_response"
    echo
    
    # Look for file creation/editing patterns - simple approach
    if echo "$ai_response" | grep -q -F '```'; then
        echo -e "${YELLOW}Detected code blocks in response.${NC}"
        echo "To implement the suggested code:"
        echo "1. Copy the code from the response above"
        echo "2. Create/edit the appropriate files manually"
        echo "3. Future versions will have automatic file creation"
    fi
}

# Interactive mode
interactive_mode() {
    echo -e "${CYAN}AI Code Assistant - Interactive Mode${NC}"
    echo "Type 'help' for commands, 'exit' to quit"
    echo
    
    while true; do
        echo -n "ai-code> "
        read -r input
        
        case "$input" in
            "exit"|"quit")
                log_info "Exiting interactive mode"
                break
                ;;
            "help")
                echo "Available commands: create, edit, analyze, refactor, test, debug, explain, workspace, clear, exit"
                ;;
            "workspace")
                show_workspace
                ;;
            "clear")
                clear
                ;;
            "")
                continue
                ;;
            *)
                # Parse interactive command
                local cmd_parts
                read -ra cmd_parts <<< "$input"
                local cmd="${cmd_parts[0]}"
                local request="${input#* }"
                
                if [[ "$cmd" == "$request" ]]; then
                    cmd="explain"
                    request="$input"
                fi
                
                execute_ai_command "$cmd" "$request" "" "" true false false
                ;;
        esac
        echo
    done
}

# Execute AI command
execute_ai_command() {
    local command="$1"
    local request="$2"
    local files="$3"
    local language="$4"
    local auto_confirm="${5:-false}"
    local dry_run="${6:-false}"
    local backup="${7:-false}"
    
    log_info "Executing: $command - $request"
    
    # Get workspace context
    local workspace_context
    workspace_context=$(get_workspace_context)
    
    # Create AI prompt
    local payload
    payload=$(create_ai_prompt "$command" "$request" "$files" "$language" "$workspace_context")
    
    # Make AI request
    log_info "About to call make_ai_request with:"
    log_info "  Endpoint: '${API_ENDPOINT:-}'"
    log_info "  API Key: '${API_KEY:0:8}...${API_KEY: -8}'"
    log_info "  Payload length: ${#payload}"
    
    local ai_response
    ai_response=$(make_ai_request "${API_ENDPOINT:-}" "${API_KEY:-}" "$payload")
    
    if [[ $? -eq 0 ]]; then
        # Process the response
        case "$command" in
            "create"|"edit"|"refactor")
                extract_file_operations "$ai_response" "$dry_run" "$auto_confirm" "$backup"
                ;;
            *)
                echo -e "${CYAN}AI Response:${NC}"
                echo "$ai_response"
                ;;
        esac
    else
        log_error "AI request failed"
        return 1
    fi
}

# Main function
main() {
    local command=""
    local request=""
    local config_file="$CONFIG_FILE"
    local files=""
    local language=""
    local target_dir="$WORKSPACE_DIR"
    local auto_confirm="false"
    local dry_run="false"
    local backup="false"
    local verbose="false"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -c|--config)
                config_file="$2"
                shift 2
                ;;
            -e|--endpoint)
                API_ENDPOINT="$2"
                shift 2
                ;;
            -k|--key)
                API_KEY="$2"
                shift 2
                ;;
            -m|--model)
                MODEL="$2"
                shift 2
                ;;
            -t|--temperature)
                TEMPERATURE="$2"
                shift 2
                ;;
            -T|--max-tokens)
                MAX_TOKENS="$2"
                shift 2
                ;;
            -f|--files)
                files="$2"
                shift 2
                ;;
            -d|--directory)
                target_dir="$2"
                WORKSPACE_DIR="$target_dir"
                shift 2
                ;;
            -l|--language)
                language="$2"
                shift 2
                ;;
            -w|--workspace)
                show_workspace
                exit 0
                ;;
            -y|--yes)
                auto_confirm="true"
                shift
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            --backup)
                backup="true"
                shift
                ;;
            -v|--verbose)
                verbose="true"
                shift
                ;;
            --setup)
                setup_config
                ;;
            create|edit|analyze|refactor|test|debug|explain|interactive)
                command="$1"
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                exit 1
                ;;
            *)
                if [[ -z "$request" ]]; then
                    request="$1"
                else
                    request="$request $1"
                fi
                shift
                ;;
        esac
    done
    
    # Set verbose flag
    VERBOSE="$verbose"
    
    # Check dependencies
    check_dependencies
    
    # Load configuration
    load_config "$config_file"
    
    # Use command line arguments or config defaults or environment variables
    export API_ENDPOINT="${API_ENDPOINT:-}"
    export API_KEY="${API_KEY:-${COPILOT_KEY:-}}"
    export MODEL="${MODEL:-${DEFAULT_MODEL:-$DEFAULT_MODEL}}"
    export TEMPERATURE="${TEMPERATURE:-${DEFAULT_TEMPERATURE:-$DEFAULT_TEMPERATURE}}"
    export MAX_TOKENS="${MAX_TOKENS:-${DEFAULT_MAX_TOKENS:-$DEFAULT_MAX_TOKENS}}"
    
    # Debug API key loading
    log_info "Environment COPILOT_KEY: ${COPILOT_KEY:0:8}...${COPILOT_KEY: -8}"
    log_info "Final API_KEY: ${API_KEY:0:8}...${API_KEY: -8}"
    
    # Validate required parameters
    if [[ -z "$API_ENDPOINT" ]]; then
        log_error "API endpoint is required. Use --endpoint or run --setup."
        exit 1
    fi
    
    if [[ -z "$API_KEY" ]]; then
        log_error "API key is required. Use --key, set COPILOT_KEY environment variable, or run --setup."
        exit 1
    fi
    
    # Initialize session log
    mkdir -p "$(dirname "$SESSION_LOG")"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SESSION] Started in $WORKSPACE_DIR" >> "$SESSION_LOG"
    
    # Handle commands
    if [[ "$command" == "interactive" ]] || [[ -z "$command" && -z "$request" ]]; then
        interactive_mode
    elif [[ -n "$command" ]]; then
        if [[ -z "$request" ]]; then
            log_error "Request description is required for $command command."
            exit 1
        fi
        execute_ai_command "$command" "$request" "$files" "$language" "$auto_confirm" "$dry_run" "$backup"
    elif [[ -n "$request" ]]; then
        # If no command specified but request given, default to 'explain'
        execute_ai_command "explain" "$request" "$files" "$language" "$auto_confirm" "$dry_run" "$backup"
    else
        interactive_mode
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
