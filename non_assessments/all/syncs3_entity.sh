#!/bin/bash

# Script to upload a specific entity to S3
# Usage: ./syncs3_entity.sh <entity_name> [output_directory]
# Example: ./syncs3_entity.sh students ./output
# Example: ./syncs3_entity.sh schools /path/to/custom/output

# Function to display usage
usage() {
    echo "Usage: $0 <entity_name> [output_directory]"
    echo ""
    echo "Arguments:"
    echo "  entity_name       The name of the entity directory to upload (required)"
    echo "  output_directory  Base directory containing entity folders (optional, defaults to './output')"
    echo ""
    echo "Examples:"
    echo "  $0 students                    # Upload students from ./output/students/"
    echo "  $0 schools ./output           # Upload schools from ./output/schools/"
    echo "  $0 staffs /custom/path        # Upload staffs from /custom/path/staffs/"
    echo ""
    echo "Available entity types:"
    echo "  calendars, staffs, students, schools, localEducationAgencies,"
    echo "  stateEducationAgencies, educationOrganizations, calendarDates,"
    echo "  classPeriods, sections, programs, courseOfferings, courses,"
    echo "  gradingPeriods, sessions, assessments, disciplineIncidents,"
    echo "  educationOrganizationNetworks, educationServiceCenters,"
    echo "  studentParentAssociations, locations, disciplineActions"
    exit 1
}

# Check if entity name is provided
if [ $# -lt 1 ]; then
    echo "Error: Entity name is required"
    usage
fi

# Get parameters
ENTITY_NAME="$1"
OUTPUT_DIR="${2:-./output}"

# S3 bucket and path prefix
S3_BUCKET="stadium-boston-airflow-dev-external"
S3_BASE_PATH="boston/historic"

# Get today's date in YYYYMMDD format
TODAY=$(date +"%Y%m%d")

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
        "educationOrganizationNetworkAssociations") echo "education_organization_network_associations" ;;
        "locations") echo "locations" ;;
        "disciplineActions") echo "discipline_actions" ;;
        "studentEducationOrganizationAssociations") echo "student_education_organization_associations" ;;
        "studentDisciplineIncidentBehaviorAssociations") echo "student_discipline_incident_behavior_associations" ;;

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

# Main processing
echo "Starting S3 sync process for entity: $ENTITY_NAME"
echo "Output directory: $OUTPUT_DIR"

# Check if the entity directory exists
entity_dir="$OUTPUT_DIR/$ENTITY_NAME"
if [ ! -d "$entity_dir" ]; then
    echo "Error: Entity directory '$entity_dir' does not exist"
    echo "Available entities in $OUTPUT_DIR:"
    if [ -d "$OUTPUT_DIR" ]; then
        ls -1 "$OUTPUT_DIR/" | grep -v '\.' | head -10
        if [ $(ls -1 "$OUTPUT_DIR/" | grep -v '\.' | wc -l) -gt 10 ]; then
            echo "... and $(expr $(ls -1 "$OUTPUT_DIR/" | grep -v '\.' | wc -l) - 10) more"
        fi
    else
        echo "Output directory '$OUTPUT_DIR' does not exist"
    fi
    exit 1
fi

echo "Found entity directory: $entity_dir"

# Process year directories within the entity
year_count=0
for year_dir in "$entity_dir"/*/ ; do
    if [ -d "$year_dir" ]; then
        # Remove trailing slash
        year_dir=${year_dir%/}
        process_year_directory "$ENTITY_NAME" "$year_dir"
        ((year_count++))
    fi
done

if [ $year_count -eq 0 ]; then
    echo "Warning: No year directories found in $entity_dir"
    echo "Looking for files directly in the entity directory..."
    
    # Check if there are JSON files directly in the entity directory
    json_files_found=false
    for json_file in "$entity_dir"/*.json*; do
        if [[ -f "$json_file" ]]; then
            json_files_found=true
            filename=$(basename "$json_file")
            edfi_resource=$(get_edfi_resource_name "$ENTITY_NAME")
            
            # Upload directly (assume current year or use a default)
            current_year=$(date +"%Y")
            s3_path="s3://$S3_BUCKET/$S3_BASE_PATH/$current_year/$TODAY/$edfi_resource/$filename"
            
            echo "Uploading $json_file to $s3_path"
            aws s3 cp "$json_file" "$s3_path"
            
            if [ $? -eq 0 ]; then
                echo "✅ Successfully processed $filename"
            else
                echo "❌ Failed to process $filename"
            fi
        fi
    done
    
    if [ "$json_files_found" = false ]; then
        echo "No JSON/JSONL files found in $entity_dir"
        exit 1
    fi
else
    echo "Processed $year_count year directories"
fi

echo "S3 sync completed for entity: $ENTITY_NAME!"
