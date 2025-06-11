#!/bin/bash

# Base directory for output files
OUTPUT_DIR="./output"

# S3 bucket and path prefix
S3_BUCKET="stadium-boston-airflow-dev-external"
S3_BASE_PATH="boston/historic"

# Get today's date in YYYYMMDD format
TODAY=$(date +"%Y%m%d")
#create an include list for the directories
#INCLUDE_DIR_NAMES=("stateEducationAgencies") # Specify the entity types to include

# Define Ed-Fi resource name mapping (folder to snake_case)
# This maps directory names to their Ed-Fi API resource names
function get_edfi_resource_name() {
    local dir_name=$1
    
    case "$dir_name" in
        "calendars") echo "calendars" ;;
        "staffs") echo "staffs" ;;
        "students") echo "students" ;;
        "schools") echo "schools" ;;
        "localEducationAgencies") echo "local_education_agencies" ;;
        "stateEducationAgencies") echo "state_education_agencies" ;;
        "educationOrganizations") echo "education_organizations" ;;
        "calendarDates") echo "calendar_dates" ;;
        "classPeriods") echo "class_periods" ;;
        "sections") echo "sections" ;;
        "programs") echo "programs" ;;
        "courseOfferings") echo "course_offerings" ;;
        "courses") echo "courses" ;;
        "gradingPeriods") echo "grading_periods" ;;
        "sessions") echo "sessions" ;;
        "assessments") echo "assessments" ;;
        "disciplineIncidents") echo "discipline_incidents" ;;
        "educationOrganizationNetworks") echo "education_organization_networks" ;;
        "educationServiceCenters") echo "education_service_centers" ;;
        "studentParentAssociations") echo "student_parent_associations" ;;
        "educationOrganizationNetworks") echo "education_organization_networks" ;;
        "educationOrganizationNetworkAssociations") echo "education_organization_network_associations" ;;
        "locations") echo "locations" ;;
        "gradingPeriods") echo "grading_periods" ;;
        "disciplineActions") echo "discipline_actions" ;;


       * ) echo "${dir_name,,}" | sed 's/\([A-Z]\)/_\L\1/g' | sed 's/^_//' ;;
    esac
}

# Function to process files in a year directory
function process_year_directory() {
    local entity_type=$1
    local year_dir=$2
    local year=$(basename "$year_dir")
    
    echo "Processing $entity_type for year $year..."
    
    # Get the corresponding Ed-Fi resource name
    edfi_resource=$(get_edfi_resource_name "$entity_type")
    
    # Find all JSON/JSONL files
    for json_file in "$year_dir"/*.json*; do
        if [[ -f "$json_file" ]]; then
            filename=$(basename "$json_file")
            # Skip files for years less than 2012
            if [[ "$year" -lt 2012 ]]; then
                #echo "Skipping $filename as the year is less than 2012"
                continue
            fi
            
            # Construct S3 path
            s3_path="s3://$S3_BUCKET/$S3_BASE_PATH/$year/$TODAY/$edfi_resource/$filename"
            
            # Upload file directly
            echo "Uploading $json_file to $s3_path"
            aws s3 cp "$json_file" "$s3_path"
            
            # Check if upload was successful
            if [ $? -eq 0 ]; then
                echo "✅ Successfully processed $filename"
            else
                echo "❌ Failed to process $filename"
            fi
        fi
    done
}

# Main processing loop
echo "Starting S3 sync process..."

# First level: entity type directories
for entity_dir in "$OUTPUT_DIR"/*/ ; do
    if [ -d "$entity_dir" ]; then
        # Remove trailing slash
        entity_dir=${entity_dir%/}
        entity_type=$(basename "$entity_dir")
        
        # Second level: year directories
        for year_dir in "$entity_dir"/*/ ; do
            if [ -d "$year_dir" ]; then
                # Remove trailing slash
                year_dir=${year_dir%/}
                process_year_directory "$entity_type" "$year_dir"
            fi
        done
    fi
done

echo "S3 sync completed!"   