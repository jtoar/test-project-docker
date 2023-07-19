#!/bin/bash

start_time="$(date -u +%s)"

# Ensure dive and dockle are installed
if ! command -v dive &> /dev/null; then
  echo "dive could not be found. Please install dive and try again."
  exit 1
fi
if ! command -v dockle &> /dev/null; then
  echo "dockle could not be found. Please install dockle and try again."
  exit 1
fi

# Get the input dockerfile
if [ $# -eq 0 ]; then
  echo "No dockerfile specified. Please specify a dockerfile as the first argument."
  exit 1
fi
input_dockerfile="$1"
echo "Input dockerfile: $input_dockerfile"

# Define the output filename
output_file="dockerfile_testing.log"

# Truncate the file by redirecting an empty string to it
> "$output_file"

# Determine if verbose
if [ -z "$1" ]; then
  detailed_output="$output_file"
else
  detailed_output="/dev/null"
fi

# Extract all targets from the Dockerfile
available_targets=$(awk '/^FROM/ && / as / {print $NF}' "$input_dockerfile")

# Output the extracted targets
echo "Targets found in $input_dockerfile:"
for target in $available_targets; do
  echo " -> $target"
done

# # Loop over the available targets and run various commands
echo "Running analysis on each target..."
for target in $available_targets; do
  echo " -> $target"

  printf '=%.0s' {1..120} >> "$output_file"
  echo >> "$output_file"
  echo "$target" >> "$output_file"
  printf '=%.0s' {1..120} >> "$output_file"
  echo >> "$output_file"

  # Build the docker image
  echo "   -> build"
  CI=1 docker build --target "$target" -t "dockerfile_testing:$target" -f "$input_dockerfile" . > "$detailed_output" 2>&1
  status=$?
  if [ $status -ne 0 ]; then
    echo "Build failed with status $status" >> "$output_file"
    echo >> "$output_file"
    continue
  fi

  # Show the docker image size
  echo "   -> size"
  echo "Docker image size:" >> "$output_file"
  docker images "dockerfile_testing:$target" --format "{{.Size}}" >> "$output_file"
  echo >> "$output_file"

  # Run dive on the target
  echo "   -> dive"
  echo "Dive results:" >> "$output_file"
  CI=1 dive "dockerfile_testing:$target" | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2};?)?)?[mGK]//g" >> "$output_file"
  echo >> "$output_file"

  # Run dockle on the target
  echo "   -> dockle"
  echo "Dockle results:" >> "$output_file"
  CI=1 dockle "dockerfile_testing:$target" --no-color | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2};?)?)?[mGK]//g" >> "$output_file"
  echo >> "$output_file"

  # Remove the docker image
  echo "   -> cleanup"
  docker rmi "dockerfile_testing:$target" > "$detailed_output" 2>&1

  echo >> "$output_file"
done

# Show done message with elapsed time
end_time="$(date -u +%s)"
elapsed="$(($end_time-$start_time))"
echo
echo "Complete in $elapsed seconds. The output has been saved to $output_file."
