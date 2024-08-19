#!/bin/bash

VERSION="1.0.0"

# Function to display help
show_help() {
    echo "Subsnap - Subdomain Takeover Vulnerability Scanner"
    echo "Usage: subsnap [OPTIONS]"
    echo
    echo "Options:"
    echo " -d, --domain DOMAIN        Target domain to scan (required)"
    echo " -o, --output DIR           Output directory (default: /DOMAIN)"
    echo " -t, --timeout SECONDS      Timeout for Eyewitness (default: 60)"
    echo " -c, --concurrency NUM      Concurrency for HTTP probes (default: 50)"
    echo " -s, --skip-screenshots     Skip screenshot capturing using eyewitness"
    echo " -v, --verbose              Enable verbose output"
    echo " -h, --help                 Show help message"
    echo " --version                  Show version information" 
}

# Function to display version
show_version() {
    echo "Subsnap v$VERSION"
}

# Function to display a custom banner
function display_banner() {
    echo -e "\033[1;35m"
    echo "   _____       _                                 "
    echo "  / ____|     | |                                "
    echo " | (___  _   _| |__  ___ _ __   __ _ _ __        "
    echo "  \___ \| | | | '_ \/ __| '_ \ / _\` | '_ \      "
    echo "  ____) | |_| | |_) \__ \ | | | (_| | |_) |      "
    echo " |_____/ \__,_|_.__/|___/_| |_|\__,_| .__/       "
    echo "                                    | |          "
    echo "                                    |_|   v$VERSION"
    echo
    echo -e "\033[1;32m        Subdomain Takeover Vulnerability Scanner\033[0m"
    echo
    echo -e "\033[1;34m Starting Subsnap...\033[0m"
    echo "============================================================"
    echo -e "\033[0m"
}

# Function to check CNAME records
function check_cname() {
    local subdomain=$1
    local cname_record=$(dig +short CNAME "$subdomain" 2>/dev/null)
    if [[ ! -z "$cname_record" ]]; then
        echo "$subdomain -> CNAME -> IN -> $cname_record" >> "$cname_output"
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Main Function
main() {
    local domain=""
    local output_dir=""
    local timeout=60
    local concurrency=50
    local skip_screenshots=false
    local verbose=false

    # Parse command-line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--domain)
                domain="$2"
                shift 2
                ;;
            -o|--output)
                output_dir="$2"
                shift 2
                ;;
            -t|--timeout)
                timeout="$2"
                shift 2
                ;;
            -c|--concurrency)
                concurrency="$2"
                shift 2
                ;;
            -s|--skip-screenshots)
                skip_screenshots=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            --version)
                show_version
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Check if domain was provided
    if [ -z "$domain" ]; then
        echo "Domain name is required. Use -d option to specify the domain."
        exit 1
    fi

    # Extract the first part of the domain name
    domain_prefix=$(echo "$domain" | cut -d '.' -f 1)

    # Set output directory if not specified
    if [ -z "$output_dir" ]; then
        output_dir="${domain_prefix}"
    fi

    # Create output directory
    mkdir -p "../$output_dir"

    # Define output files
    subfinder_output="../${output_dir}/subfinder_subdomains.txt"
    assetfinder_output="../${output_dir}/assetfinder_subdomains.txt"
    sublist3r_output="../${output_dir}/sublist3r_subdomains.txt"
    merged_output="../${output_dir}/all_subdomains.txt"
    alive_output="../${output_dir}/alive_subdomains.txt"
    alive_output_code="../${output_dir}/alive_subdomains_with_codes.txt"
    subzy_output="../${output_dir}/subzy_output.txt"
    subzy_vulnerable_output="../${output_dir}/subzy_vulnerable_subdomains.txt"
    cname_output="../${output_dir}/cname_records.txt"

    # Display the banner
    display_banner

    # Check for required tools
    local required_tools=("subfinder" "assetfinder" "sublist3r" "httpx-toolkit" "subzy" "eyewitness")
    for tool in "${required_tools[@]}"; do
        if ! command_exists "$tool"; then
            echo "Error: $tool is not installed or not in PATH. Please install it and try again."
            exit 1
        fi
    done

    # Step 1: Subfinder
    echo -e "\033[1;34m[*] Running Subfinder...\033[0m"
    subfinder -d "$domain" -silent -all > "$subfinder_output"
    echo -e "\033[1;32m[+] Subfinder found $(wc -l < "$subfinder_output") subdomains\033[0m"

    # Step 2: Assetfinder
    echo -e "\033[1;34m[*] Running Assetfinder...\033[0m"
    assetfinder --subs-only "$domain" > "$assetfinder_output"
    echo -e "\033[1;32m[+] Assetfinder found $(wc -l < "$assetfinder_output") subdomains\033[0m"

    # Step 3: Sublist3r
    echo -e "\033[1;34m[*] Running Sublist3r...\033[0m"
    sublist3r -d "$domain" -o "$sublist3r_output" > /dev/null
    echo -e "\033[1;32m[+] Sublist3r found $(wc -l < "$sublist3r_output") subdomains\033[0m"

    # Step 4: Merge Subdomains
    echo -e "\033[1;34m[*] Merging subdomains...\033[0m"
    sort -u "$subfinder_output" "$assetfinder_output" "$sublist3r_output" > "$merged_output"
    echo -e "\033[1;32m[+] Total unique subdomains: $(wc -l < "$merged_output")\033[0m"

    # Step 5: Get Live Subdomains
    echo -e "\033[1;34m[*] Checking for live subdomains...\033[0m"
    httpx-toolkit -silent -l "$merged_output" > "$alive_output"
    echo -e "\033[1;32m[+] Live subdomains: $(wc -l < "$alive_output")\033[0m"

    # Step 6: Get Live Subdomains with Status Codes
    echo -e "\033[1;34m[*] Checking live subdomains with status codes...\033[0m"
    httpx-toolkit -silent -sc -l "$merged_output" > "$alive_output_code"
    echo -e "\033[1;32m[+] Live subdomains with status codes: $(wc -l < "$alive_output_code")\033[0m"

    # Step 7: Check for Subdomain Vulnerabilities using Subzy
    echo -e "\033[1;34m[*] Running Subzy to check for vulnerable subdomains...\033[0m"
    subzy run --targets "$alive_output" | grep "VULNERABLE" > "$subzy_vulnerable_output"
    echo -e "\033[1;32m[+] Vulnerable subdomains saved to: $subzy_vulnerable_output\033[0m"

    # Step 8: Check for CNAME Records
    echo -e "\033[1;34m[*] Checking CNAME records...\033[0m"
    > "$cname_output"
    while IFS= read -r subdomain; do
        check_cname "$subdomain"
    done < "$alive_output"
    echo -e "\033[1;32m[+] CNAME records [$(wc -l < "$cname_output")] saved to: $cname_output\033[0m"

    # Step 8.5: Grep specific CNAME patterns
    echo -e "\033[1;34m[*] Checking for specific CNAME patterns...\033[0m"
    grep_output="../${output_dir}/specific_cname_patterns.txt"
    {
        echo "    [->] Checking for Github Pages:"
        grep -E "github" "$cname_output"
        echo "    [->] Checking for Amazon S3:"
        grep -E '.s3.amazonaws.com' "$cname_output"
        grep -E '.s3-website' "$cname_output"
        grep -E '.s3' "$cname_output"
        echo
        echo "    [->] Checking for Heroku:"
        grep -E 'herokudns' "$cname_output"
        echo
        echo "    [->] Checking for ReadMe.io:"
        grep -E 'readme' "$cname_output"
    } > "$grep_output"

    if [ -s "$grep_output" ]; then
        echo -e "\033[1;32m[+] Specific CNAME patterns found and saved to: $grep_output\033[0m"
    else
        echo -e "\033[1;33m[-] No specific CNAME patterns found.\033[0m"
        rm "$grep_output"
    fi

    # Step 9: Capture Screenshots
    if [ "$skip_screenshots" = false ]; then
        echo -e "\033[1;34m[*] Capturing screenshots with Eyewitness...\033[0m"
        eyewitness -f "$alive_output" -d "$output_dir/screenshots" --timeout "$timeout" > /dev/null 2>&1
        echo -e "\033[1;32m[+] Screenshots captured and saved in $output_dir/screenshots\033[0m"
    else
        echo -e "\033[1;32m[-] Skipping screenshot capture step\033[0m"
    fi

    # Final message
    echo -e "\033[1;33m[!] Subsnap scan completed. Results are in the $output_dir directory.\033[0m"
}

# Run the main function
main "$@"
