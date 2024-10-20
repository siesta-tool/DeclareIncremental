#!/bin/bash

DIRECTORY=/app/output
RESULT=/app/output/results.txt
PREFIX=$1
SPARK_SUBMIT_COMMAND="/opt/spark/bin/spark-submit --master local[*] --driver-memory 50g --conf spark.eventLog.enabled=true --conf spark.eventLog.dir=/tmp/spark-events"
PREPROCESS_JAR="/app/preprocess.jar"
EXTRACTION_JAR="/app/declare.jar"

export s3accessKeyAws=minioadmin
export s3ConnectionTimeout=600000
export s3endPointLoc=http://minio:9000
export s3secretKeyAws=minioadmin

# Check if the directory exists
if [ -d "$DIRECTORY" ]; then
  # Find files that match the prefix and sort them by the numeric part
  find "$DIRECTORY" -type f -name "${PREFIX}*" | sort -V | while read file; do
    # Print the filename
    FILENAME=$(basename "$file")
    echo "Processing $FILENAME" >> $RESULT

     # Run Spark job using spark-submit and capture the output
      output=$($SPARK_SUBMIT_COMMAND "$PREPROCESS_JAR" -f "$file" --logname "$PREFIX" --lookback 2 2>&1)

      # Check if the Spark job failed
      if [ $? -ne 0 ]; then
        echo "Error processing $FILENAME" >> $RESULT
      else
        echo "$FILENAME processed successfully" >> $RESULT
      fi

      # Extract the "Time taken" from the output and print it
      echo "$output" | grep -oP 'Time taken: \d+ ms' >> $RESULT
      echo "Extracting declare constraints" >> $RESULT

      #Run again spark-submit to extract declare constraints
      output=$($SPARK_SUBMIT_COMMAND "$EXTRACTION_JAR" "$PREFIX" 0 2>&1)
      echo "$output" | grep -oP 'Time taken: \d+ ms' >> $RESULT


      # Check if the Spark job failed
      if [ $? -ne 0 ]; then
        echo "Error mining $FILENAME" >> $RESULT
      else
        echo "Mined successfully" >> $RESULT
      fi

  done
else
  echo "Directory not found!"
fi