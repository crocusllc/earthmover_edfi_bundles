#!/bin/bash
# filepath: /home/bruk/code/boston/earthmover_edfi_bundles/non_assessments/all/validation.sh

# Set the base directory
BASE_DIR="/home/bruk/code/boston/earthmover_edfi_bundles"
# Set the path to the lightbeam config file
LIGHTBEAM_CONFIG="${BASE_DIR}/non_assessments/all/lightbeam.yml"
OUTPUT_DIR="${BASE_DIR}/non_assessments/all/output"

# Check if output directory exists
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Error: Output directory does not exist: $OUTPUT_DIR"
    exit 1
fi

# First loop: iterate through entity types (directories under output/)
for entity_dir in "$OUTPUT_DIR"/*/ ; do
    if [ -d "$entity_dir" ]; then
        # Remove trailing slash for cleaner path handling
        entity_dir=${entity_dir%/}
        entity_type=$(basename "$entity_dir")
        echo "Processing entity type: $entity_type"
        
        # Second loop: iterate through year directories under each entity type
        for year_dir in "$entity_dir"/*/ ; do
            if [ -d "$year_dir" ]; then
                # Remove trailing slash for cleaner path handling
                year_dir=${year_dir%/}
                year=$(basename "$year_dir")
                echo "  Processing year: $year for $entity_type"
                
                # Find all JSONL files in the year directory
                json_files=$(find "$year_dir" -name "*.jsonl" -type f)
                
                if [ -z "$json_files" ]; then
                    echo "    Warning: No JSONL files found in $year_dir - skipping"
                    continue
                fi
                
                # Print found files for debugging
                echo "    Found files:"
                for file in $json_files; do
                    echo "      - $(basename "$file")"
                done
                
                # Create a temporary config file with the updated data_dir
                TEMP_CONFIG=$(mktemp)
                
                # Copy the original config
                cp "$LIGHTBEAM_CONFIG" "$TEMP_CONFIG"
                
                # Update the data_dir to point to the specific year directory
                # Make sure there's no double slash in the path
                clean_path="$year_dir"
                sed -i "s|data_dir: .*|data_dir: ${clean_path}|g" "$TEMP_CONFIG"
                
                # Set the selector based on entity type
                # Convert to lowercase and strip trailing 's' if it exists for API endpoint compatibility
                endpoint=$(echo "$entity_type" | tr '[:upper:]' '[:lower:]')
                
                # Special case handling for plural/singular conversions
                case "$endpoint" in
                    "calendars") endpoint="calendars" ;;
                    "stateeducationagencies") endpoint="stateEducationAgencies" ;;
                    "localeducationagencies") endpoint="localEducationAgencies" ;;
                    "educationorganizations") endpoint="educationOrganizations" ;;
                    "educationservicecenters") endpoint="educationServiceCenters" ;;
                    "schools") endpoint="schools" ;;
                    "staffs") endpoint="staffs" ;;
                    "students") endpoint="students" ;;
                    "sections") endpoint="sections" ;;
                    "programs") endpoint="programs" ;;
                    # Add more cases as needed
                esac
                
                # Add or update the selector section
                if ! grep -q "selector:" "$TEMP_CONFIG"; then
                    echo "" >> "$TEMP_CONFIG"
                    echo "selector:" >> "$TEMP_CONFIG"
                    echo "  include:" >> "$TEMP_CONFIG"
                    echo "    - $endpoint" >> "$TEMP_CONFIG"
                else
                    # Update existing selector to include the current entity type
                    sed -i '/selector:/,/include:/s/include:.*/include:\n    - '"$endpoint"'/' "$TEMP_CONFIG"
                fi
                
                echo "    Running lightbeam validation for $entity_type year $year"
                echo "    Using config with path: ${clean_path}"
                cat "$TEMP_CONFIG" | grep -E "data_dir|selector"
                
                # Run lightbeam validate command
                lightbeam validate --config="$TEMP_CONFIG"
                
                # Capture the exit status
                STATUS=$?
                
                # Remove temporary config file
                rm "$TEMP_CONFIG"
                
                if [ $STATUS -eq 0 ]; then
                    echo "    ✅ Validation successful for $entity_type year $year"
                else
                    echo "    ❌ Validation failed for $entity_type year $year"
                fi
                
                echo "    -----------------------------------------"
            fi
        done
    fi
done

echo "All entity validations complete."