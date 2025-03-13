#!/bin/bash
# filepath: /home/bruk/code/boston/earthmover_edfi_bundles/non_assessments/all/list_s3_uploads.sh

# S3 bucket and path prefix
S3_BUCKET="stadium-boston-airflow-dev-external"
S3_BASE_PATH="boston/historic"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Show header
echo -e "${BLUE}=== S3 Upload Listing ===${NC}"
echo "Bucket: $S3_BUCKET"
echo "Base Path: $S3_BASE_PATH"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if we can access the bucket
if ! aws s3 ls "s3://$S3_BUCKET/$S3_BASE_PATH/" &> /dev/null; then
    echo "Error: Cannot access S3 bucket or path. Check permissions or if the bucket exists."
    exit 1
fi

# List years
echo -e "${BLUE}Available Years:${NC}"
YEARS=$(aws s3 ls "s3://$S3_BUCKET/$S3_BASE_PATH/" | grep PRE | awk '{print $2}' | sed 's/\///')

if [ -z "$YEARS" ]; then
    echo "No years found in the bucket."
    exit 0
fi

# Loop through each year
for YEAR in $YEARS; do
    echo -e "\n${YELLOW}Year: $YEAR${NC}"
    
    # List dates for this year
    DATES=$(aws s3 ls "s3://$S3_BUCKET/$S3_BASE_PATH/$YEAR/" | grep PRE | awk '{print $2}' | sed 's/\///')
    
    if [ -z "$DATES" ]; then
        echo "  No dates found for this year."
        continue
    fi
    
    # Loop through each date
    for DATE in $DATES; do
        echo -e "  ${GREEN}Date: $DATE${NC}"
        
        # List Ed-Fi resources for this date
        RESOURCES=$(aws s3 ls "s3://$S3_BUCKET/$S3_BASE_PATH/$YEAR/$DATE/" | grep PRE | awk '{print $2}' | sed 's/\///')
        
        if [ -z "$RESOURCES" ]; then
            echo "    No resources found for this date."
            continue
        fi
        
        # Loop through each resource
        for RESOURCE in $RESOURCES; do
            # Count files and get total size
            FILE_INFO=$(aws s3 ls --recursive --summarize "s3://$S3_BUCKET/$S3_BASE_PATH/$YEAR/$DATE/$RESOURCE/")
            FILE_COUNT=$(echo "$FILE_INFO" | grep "Total Objects" | awk '{print $3}')
            TOTAL_SIZE=$(echo "$FILE_INFO" | grep "Total Size" | awk '{print $3" "$4}')
            
            echo -e "    ${BLUE}Resource: $RESOURCE${NC} - $FILE_COUNT files ($TOTAL_SIZE)"
            
            # Show detailed file list (limit to 5 files to avoid cluttering output)
            FILE_LIST=$(aws s3 ls "s3://$S3_BUCKET/$S3_BASE_PATH/$YEAR/$DATE/$RESOURCE/" | head -n 5)
            
            if [ -n "$FILE_LIST" ]; then
                echo "      Files (showing up to 5):"
                echo "$FILE_LIST" | while read -r line; do
                    FILE_SIZE=$(echo "$line" | awk '{print $3}')
                    FILE_DATE=$(echo "$line" | awk '{print $1, $2}')
                    FILE_NAME=$(echo "$line" | awk '{print $4}')
                    echo "        $FILE_NAME (${FILE_SIZE} bytes, uploaded on $FILE_DATE)"
                done
                
                # If there are more than 5 files, show a message
                if [ "$FILE_COUNT" -gt 5 ]; then
                    REMAINING=$((FILE_COUNT - 5))
                    echo "        ... and $REMAINING more file(s)"
                fi
            fi
            
            # Add a command to show all files for this resource
            echo "      To list all files: aws s3 ls s3://$S3_BUCKET/$S3_BASE_PATH/$YEAR/$DATE/$RESOURCE/"
        done
    done
done

# Show a summary
TOTAL_FILES=$(aws s3 ls --recursive --summarize "s3://$S3_BUCKET/$S3_BASE_PATH/" | grep "Total Objects" | awk '{print $3}')
TOTAL_SIZE=$(aws s3 ls --recursive --summarize "s3://$S3_BUCKET/$S3_BASE_PATH/" | grep "Total Size" | awk '{print $3" "$4}')

echo -e "\n${BLUE}Summary:${NC}"
echo "Total Files: $TOTAL_FILES"
echo "Total Size: $TOTAL_SIZE"