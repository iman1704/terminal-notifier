# terminal-notifier (Swift Version)

A lightweight command-line interface for posting native macOS User Notifications on macOS 10.15 and higher, written in Swift.

---

## 1. Project Overview and Quick-Start

### Overview
This project is a modern, Swift-based implementation of the popular `terminal-notifier` CLI tool. It is delivered as a macOS application bundle (`terminal-notifier.app`). Running the executable inside this bundle registers notifications under the bundle's identifier, ensuring full integration with macOS Notification Center permissions, sounds, and click actions.

### Quick-Start
To compile and test the tool immediately:

1. Compile and package the application bundle:
   ```bash
   ./build.sh
   ```

2. Post your first notification:
   ```bash
   ./terminal-notifier.app/Contents/MacOS/terminal-notifier -message "Hello from terminal-notifier!" -title "Quick Start"
   ```

Note: On the first run, macOS will prompt you to authorize notifications for Terminal Notifier. Choose "Allow" in the system dialog to permit notifications to appear.

---

## 2. Common Commands

Below are standard use cases for the CLI:

### Post a Simple Notification
```bash
terminal-notifier -message "Build complete" -title "CI/CD" -subtitle "Status: Success"
```

### Play a Sound
```bash
terminal-notifier -message "Task Finished" -sound default
```

### Group and Replace Banners
Only one notification per group is displayed. Posting a new message with the same group ID replaces the existing notification:
```bash
terminal-notifier -message "Downloading: 10%" -group download-task
terminal-notifier -message "Downloading: 50%" -group download-task
```

### Attach Images or Custom App Icons
```bash
terminal-notifier -message "Photo Uploaded" -contentImage "/path/to/image.jpg" -appIcon "/path/to/icon.png"
```

### Click Actions
* **Open URL:** Opens the specified URL in the default browser when the notification is clicked.
  ```bash
  terminal-notifier -message "View Reports" -open "https://example.com"
  ```
* **Execute Command:** Runs a shell command when clicked.
  ```bash
  terminal-notifier -message "Process complete" -execute "say finished"
  ```

### List Active Notifications
```bash
terminal-notifier -list ALL
```

### Remove Active Notifications
```bash
terminal-notifier -remove ALL
```

### List Available Sounds
```bash
terminal-notifier -list-sounds
```

---

## 3. Project Specification, Design, and Architecture

### Specification
* **Form Factor:** Delivered as an LSUIElement macOS app bundle (`terminal-notifier.app`). It runs completely in the background with no Dock icon or menu bar.
* **Execution Model:** Stateless CLI. The program processes command-line flags, schedules notifications or modifies active ones, and then exits.
* **Target OS:** macOS 10.15+ (uses the modern UserNotifications framework).

### Design and Architecture

```
+-------------------------------------------------------+
|                       CLI Launch                      |
| (Checks if arguments are present or isatty is false)  |
+--------------------------+----------------------------+
                           |
            +--------------+--------------+
            |                             |
      [isCLI == true]              [isCLI == false]
            |                             |
            v                             v
   +-----------------+           +------------------+
   |   Run CLI Mode  |           |  Run GUI App     |
   |  (Post/List/    |           |  (Await Click    |
   |   Remove & Exit)|           |   Callback)      |
   +-----------------+           +--------+---------+
                                          |
                                          v
                                 +--------+---------+
                                 |  Execute Click   |
                                 |  Actions & Exit  |
                                 +------------------+
```

1. **Argument Parsing & Routing:**
   * If invoked with CLI arguments or via a piped input stream (non-TTY stdin), the tool runs in CLI mode.
   * If invoked by the OS (such as when a user clicks a notification), it starts the `NSApplication` run loop to capture system delegate callbacks.

2. **UserNotifications Integration:**
   * Utilizes `UNUserNotificationCenter` to post, retrieve, and delete notifications.
   * Leverages `UNNotificationAttachment` to dynamically download (for http/https) or copy local files to support custom icons (`-appIcon`) and body images (`-contentImage`).

3. **Click Persistence:**
   * Click actions (`-open`, `-execute`) are stored inside the notification content's `userInfo` dictionary.
   * When the notification is clicked, the app is launched by macOS. `AppDelegate` intercepts the click event via `UNUserNotificationCenterDelegate`, reads the `userInfo` properties, executes the corresponding action, and exits.

---

## 4. Directory Navigation

The repository contains the following files:

* **[main.swift](file:///Users/mohamadiman/Documents/Projects/scratchpad/main.swift):** Contains the core logic for argument parsing, swizzling, notification scheduling, click callback delegation, and console outputs.
* **[terminal-notifier.app/](file:///Users/mohamadiman/Documents/Projects/scratchpad/terminal-notifier.app/):** The macOS application bundle directory.
  * **[Contents/Info.plist](file:///Users/mohamadiman/Documents/Projects/scratchpad/terminal-notifier.app/Contents/Info.plist):** Contains bundle configuration, bundle identifier, and the `LSUIElement` key.
* **[build.sh](file:///Users/mohamadiman/Documents/Projects/scratchpad/build.sh):** The shell script to compile the Swift source and ad-hoc sign the executable and bundle.
* **[install.sh](file:///Users/mohamadiman/Documents/Projects/scratchpad/install.sh):** The local installation script that builds and copies the bundle to `/usr/local/share` and creates a symlink in `/usr/local/bin`.
* **[terminal-notifier.rb](file:///Users/mohamadiman/Documents/Projects/scratchpad/terminal-notifier.rb):** The Homebrew formula to compile and install the application directly using Homebrew.
* **[specification.md](file:///Users/mohamadiman/Documents/Projects/scratchpad/specification.md):** The original project specification.

---

## 5. Development, Local Installation, and Homebrew Deployment

### Development
For code modifications:
1. Edit [main.swift](file:///Users/mohamadiman/Documents/Projects/scratchpad/main.swift).
2. Test-compile using the build script:
   ```bash
   ./build.sh
   ```
3. Run the compiled local bundle:
   ```bash
   ./terminal-notifier.app/Contents/MacOS/terminal-notifier -message "Development test"
   ```

### Local Installation
To install the tool natively as a CLI application on your Mac:
```bash
./install.sh
```
This builds the bundle, copies it to `/usr/local/share/terminal-notifier`, and creates a symlink `/usr/local/bin/terminal-notifier`.

### Deploying as a Homebrew Package
A local Homebrew formula is provided at [terminal-notifier.rb](file:///Users/mohamadiman/Documents/Projects/scratchpad/terminal-notifier.rb).

To test building and installing the package locally via Homebrew:
```bash
brew install --build-from-source ./terminal-notifier.rb
```

To deploy this formula to a public Homebrew Tap:
1. Host this repository on a Git service (e.g. GitHub).
2. Create a release and download the `.tar.gz` archive.
3. Calculate the SHA256 checksum of the archive:
   ```bash
   shasum -a 256 v2.0.0.tar.gz
   ```
4. Update the `url` and `sha256` fields in the formula to point to the remote archive.
5. Commit the formula file to your Homebrew Tap repository (usually named `homebrew-tap` in a formula directory).

---

## 6. Testing

### Unit and Integration Testing
You can verify the CLI options by running commands against the built package:

1. **Verify Version command:**
   ```bash
   terminal-notifier -version
   ```
   Expected output: `2.0.0`

2. **Verify Help command:**
   ```bash
   terminal-notifier -help
   ```
   Expected output: Displays the help message block.

3. **Verify Standard Input Piping:**
   ```bash
   echo "Piped message body" | terminal-notifier -title "Standard Input Test"
   ```

4. **Verify Notification Cleanup:**
   Post a grouped notification:
   ```bash
   terminal-notifier -message "Delivered" -group temp-group
   ```
   Confirm the notification appears in the Notification Center. Then remove it:
   ```bash
   terminal-notifier -remove temp-group
   ```
   Confirm it is removed from the screen.

5. **Verify Listing Sounds:**
   ```bash
   terminal-notifier -list-sounds
   ```
   Expected output: Prints a list of available system and user audio sound names.
```
