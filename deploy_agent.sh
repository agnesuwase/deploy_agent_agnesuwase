#!/bin/bash

check_tools() {
  if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is not installed. Install it, then run this script again."
    exit 1
  fi

  python3 --version

  if ! command -v zip >/dev/null 2>&1; then
    echo "zip is not installed. Install it, then run this script again."
    exit 1
  fi

  echo "python3 and zip are both installed."
}

create_project() {
  read -r -p "Type a short name (example: v1): " name

  if [ -z "$name" ]; then
    echo "The name cannot be empty."
    exit 1
  fi

  project="attendance_tracker_${name}"

  if [ -d "$project" ]; then
    read -r -p "$project already exists. Overwrite it? Type y or n: " answer
    case "$answer" in
      y|Y)
        rm -rf "$project"
        ;;
      *)
        echo "Stopped. The old folder was left as it is."
        exit 1
        ;;
    esac
  fi

  mkdir -p "$project/Helpers" "$project/reports"
  echo "Created $project"
  echo "It contains Helpers/ and an empty reports/ folder."
  ls -l "$project"
}

copy_program_files() {
  if [ ! -f templates/attendance_checker.py ] || [ ! -f templates/config.json ] || [ ! -f templates/assets.csv ]; then
    echo "A teacher's file is missing from the templates folder."
    exit 1
  fi

  cp templates/attendance_checker.py "$project/attendance_checker.py"
  cp templates/config.json "$project/Helpers/config.json"
  echo "Copied attendance_checker.py and config.json."
}

build_roster() {
  echo "A) Copy students from the template"
  echo "B) Generate a new class list"
  read -r -p "Type A or B: " roster_choice

  case "$roster_choice" in
    a|A)
      read -r -p "How many students? Use a number from 1 to 10: " count
      if [[ ! "$count" =~ ^[0-9]+$ ]] || [ "$count" -lt 1 ] || [ "$count" -gt 10 ]; then
        echo "That count is not allowed."
        exit 1
      fi
      head -n $((count + 1)) templates/assets.csv > "$project/Helpers/assets.csv"
      echo "Copied $count students. total_sessions stays 5."
      ;;
    b|B)
      read -r -p "How many students? Use a number from 1 to 5: " count
      if [[ ! "$count" =~ ^[0-9]+$ ]] || [ "$count" -lt 1 ] || [ "$count" -gt 5 ]; then
        echo "That count is not allowed."
        exit 1
      fi

      first_names=(Alice Bob Carol David Eve)
      last_names=(Johnson Smith Brown Davis Wilson)
      emails=(alice@example.com bob@example.com carol@example.com david@example.com eve@example.com)

      echo "Email,Names,Attendance Count,Absence Count" > "$project/Helpers/assets.csv"
      i=0
      while [ "$i" -lt "$count" ]; do
        echo "${emails[$i]},${first_names[$i]} ${last_names[$i]},0,0" >> "$project/Helpers/assets.csv"
        i=$((i + 1))
      done

      sed -i 's/"total_sessions": 5/"total_sessions": 1/' "$project/Helpers/config.json"
      echo "Created $count new students. total_sessions is now 1."
      ;;
    *)
      echo "Type A or B."
      exit 1
      ;;
  esac
}

set_permissions() {
  chmod +x "$project/attendance_checker.py"
  chmod 600 "$project/Helpers/config.json"
  echo "Permissions set:"
  ls -l "$project/attendance_checker.py" "$project/Helpers/config.json"
}

update_thresholds() {
  read -r -p "Update warning and failure thresholds? Type y or n: " change
  case "$change" in
    y|Y)
      read -r -p "Warning threshold [75]: " warning
      read -r -p "Failure threshold [50]: " failure
      warning="${warning:-75}"
      failure="${failure:-50}"

      if [[ ! "$warning" =~ ^[0-9]+$ ]] || [[ ! "$failure" =~ ^[0-9]+$ ]]; then
        echo "Both thresholds must be whole numbers."
        exit 1
      fi

      sed -i "s/\"warning\": [0-9][0-9]*/\"warning\": ${warning}/" "$project/Helpers/config.json"
      sed -i "s/\"failure\": [0-9][0-9]*/\"failure\": ${failure}/" "$project/Helpers/config.json"
      echo "Thresholds updated."
      grep -n "warning\|failure" "$project/Helpers/config.json"
      ;;
    *)
      echo "Thresholds were left unchanged."
      ;;
  esac
}

run_app() {
  if [ -z "${project:-}" ]; then
    read -r -p "Type the short name you used (example: v1): " name
    project="attendance_tracker_${name}"
  fi

  if [ ! -f "$project/attendance_checker.py" ]; then
    echo "Deploy the project before running it."
    exit 1
  fi

  echo "The attendance app is starting."
  (
    cd "$project" || exit 1
    python3 attendance_checker.py
  )
}

archive_logs() {
  if [ -z "${project:-}" ]; then
    read -r -p "Type the short name you used (example: v1): " name
    project="attendance_tracker_${name}"
  fi

  if [ ! -d "$project" ]; then
    echo "That project folder does not exist."
    exit 1
  fi

  stamp="$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$project/archives/attendance" "$project/archives/absent"

  if [ -f "$project/reports/attendance.log" ]; then
    dest="$project/archives/attendance/attendance_${stamp}.log"
    cp "$project/reports/attendance.log" "$dest"
    echo "Archived attendance log to $dest"
  else
    echo "attendance.log was not found, so it was not archived."
  fi

  if [ -f "$project/reports/absent.log" ]; then
    dest="$project/archives/absent/absent_${stamp}.log"
    cp "$project/reports/absent.log" "$dest"
    echo "Archived absent log to $dest"
  else
    echo "absent.log was not found, so it was not archived."
  fi
}
deploy() {
  trap on_interrupt SIGINT SIGTSTP
  check_tools
  create_project
  copy_program_files
  build_roster
  set_permissions
  update_thresholds
  trap - SIGINT SIGTSTP
  run_app
}

on_interrupt() {
  trap - SIGINT SIGTSTP
  echo ""
  echo "Deployment was interrupted."
  if [ -n "${project:-}" ] && [ -d "$project" ]; then
    zip -r "${project}_archive.zip" "$project"
    rm -rf "$project"
    echo "Saved ${project}_archive.zip and removed the incomplete folder."
  else
    echo "No project folder existed yet, so there was nothing to zip."
  fi
  exit 1
}

echo "Student Attendance Tracker"
echo "1) Deploy the application"
echo "2) Run the application"
echo "3) Archive the logs"
echo "4) Exit"
read -r -p "Choose 1, 2, 3, or 4: " choice

case "$choice" in
  1)
  deploy
;;
  2)
    run_app
    ;;
  3)
    archive_logs
    ;;
  4)
    echo "Goodbye."
    ;;
  *)
    echo "That is not a valid choice."
    ;;
esac
