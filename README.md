
# deploy_agent

A Bash script that deploys, runs and archives logs for the Student Attendance Tracker (a Python app), with clean handling of Ctrl+C and Ctrl+Z while deploying. The Python app, `attendance_checker.py`, is never modified.

Video walkthrough: https://drive.google.com/file/d/1XZPPheJs3CIDUOtMqN4rsVeD8mJtOZNu/view?usp=sharing

## Repository contents

- `deploy_agent.sh`: the master script
- `templates/`: the three unmodified teacher files (`attendance_checker.py`, `assets.csv`, `config.json`)
- `.gitignore`: keeps generated projects, zip files and editor swap files out of the repo

## Requirements

- Linux or WSL with Bash
- `python3` and `zip` (the script checks for both)

## How to run

From the repo folder:

```bash
bash deploy_agent.sh
```

A numbered menu appears. I used an interactive menu (`read` and `case`) instead of command-line flags.

| Choice | Feature |
|---|---|
| 1 | Deploy the application |
| 2 | Run the application |
| 3 | Archive the logs |
| 4 | Exit |

Any other input prints "That is not a valid choice."

## Feature 1: Deploy

1. **Pre-flight checks.** The script checks that `python3` and `zip` are installed, prints the Python version, and stops with a clear message if either is missing.
2. **Project name.** It asks for a short name and creates `attendance_tracker_<name>/`. An empty name is rejected. If the folder already exists, the script asks whether to overwrite it. `y` rebuilds the folder, and any other answer stops without touching it.
3. **Structure created:**

```
attendance_tracker_<name>/
├── attendance_checker.py
├── Helpers/
│   ├── assets.csv
│   └── config.json
└── reports/
```

4. **Roster.** The user chooses how to build `Helpers/assets.csv`:
   - **Option A (copy):** copies N students (1 to 10) from `templates/assets.csv`. These students already have 4 prior sessions, so `total_sessions` stays **5**.
   - **Option B (generate):** builds N students (1 to 5) from name and email arrays in the script, with attendance and absence counts at 0. This is session one, so `sed` changes `total_sessions` to **1**.

   The count must be a whole number in range, or the script stops.
5. **Permissions.** `chmod +x` makes the Python file executable, and `chmod 600` makes `config.json` owner read/write only, because it holds grading thresholds. Both are printed with `ls -l` as confirmation.
6. **Thresholds.** See the next section.
7. **Verification.** The deploy finishes by running the app (Feature 2). If the app starts, the structure, roster and config work together.

## How the threshold update works

The script asks whether to update the alert thresholds. If the answer is `y`:

1. It reads new values for `warning` (default 75) and `failure` (default 50). An empty answer keeps the default.
2. It checks both values are whole numbers (`^[0-9]+$`). If not, it prints an error and stops **before** touching the file.
3. It uses `sed -i` to replace only the `"warning": <number>` and `"failure": <number>` lines in the deployed `config.json`. The file is not reformatted or reordered.
4. It prints the updated lines with `grep`.

Any other answer leaves the thresholds unchanged.

## Feature 2: Run

Choosing 2 asks for the project name (unless a deploy just ran), checks the project exists, then runs `python3 attendance_checker.py` from inside the project folder. The app is interactive: the instructor marks each student present or absent, the counts in `assets.csv` are updated, and logs are written to `reports/`.

## Feature 3: Archive

After a run, choosing 3 copies the logs into their own folders with a timestamp in the filename:

```
attendance_tracker_<name>/
└── archives/
    ├── attendance/
    │   └── attendance_YYYYMMDD_HHMMSS.log
    └── absent/
        └── absent_YYYYMMDD_HHMMSS.log
```

- The timestamp comes from `date +%Y%m%d_%H%M%S`, so every archived copy has a unique name and nothing is overwritten.
- If a log does not exist (for example, nobody was absent, so there is no `absent.log`), the script reports that and carries on without crashing.
- The script prints the final path of each archived log.

## Ctrl+C and Ctrl+Z handling

During deployment the script traps both SIGINT (Ctrl+C) and SIGTSTP (Ctrl+Z). On either signal it:

1. prints a message that the deployment was interrupted,
2. zips whatever exists of the project into `attendance_tracker_<name>_archive.zip`,
3. deletes the incomplete project folder so no half-built directory is left behind,
4. exits cleanly.

The project name is only set after the overwrite question is answered, so cancelling at that question never touches an existing project. The trap is switched off just before the app starts, so Ctrl+C during a marking session cannot delete a finished project.

### How to test it

1. Run `bash deploy_agent.sh`, choose 1, and enter a name such as `t1`.
2. At the `How many students?` question, press **Ctrl+C**.
3. Check the result:

```bash
ls
unzip -l attendance_tracker_t1_archive.zip
```

The zip should exist and the `attendance_tracker_t1` folder should be gone. Repeat with a new name and **Ctrl+Z**.

### What the zip contains

Whatever had been built at the moment of the interrupt. Interrupting at the roster question gives `Helpers/config.json`, `reports/` and `attendance_checker.py`, but no `assets.csv` yet.

## How I tested the deployed structure

- Deployed with Option A and Option B, then used `cat` on `Helpers/assets.csv` and `grep total_sessions Helpers/config.json` to check the roster and the 5 versus 1 value.
- Used `ls -l` to check the permissions (`x` on the Python file, `-rw-------` on `config.json`).
- Tested thresholds with valid numbers (80 and 40), no change, empty answers, and non-numeric input (`abc`).
- Ran a live marking session and confirmed `reports/attendance.log` and `reports/absent.log` were created.
- Archived the logs, archived twice to confirm unique timestamps, and archived a project with a missing log.
- Tested an invalid menu choice, an empty project name, and overwrite answered with `y` and `n`.
- Interrupted a deploy with Ctrl+C and with Ctrl+Z and inspected the zip with `unzip -l`.
- Cancelled at the overwrite question with Ctrl+Z and confirmed the existing folder was kept.

