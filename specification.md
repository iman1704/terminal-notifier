## Specification Document

### 1. Overview
**Purpose:** Provide a command-line interface for posting native macOS User Notifications on macOS 10.10 and higher.

**Form factor:** Delivered as a macOS application bundle (`terminal-notifier.app`). The executable must be invoked inside the bundle:
```
terminal-notifier.app/Contents/MacOS/terminal-notifier
```

**Design principle:** Stateless CLI — each invocation either posts, removes, or lists notifications, then exits.

### 2. System Context
- **Platform:** macOS 10.10+ with Notification Center running
- **Dependency:** Requires a running `com.apple.notificationcenterui` process for the current user
- **Execution model:** Runs as LSUIElement (no Dock icon, no menu)

### 3. Core Functionalities

#### 3.1 Post a Notification
**Trigger:** `-message VALUE` is provided, or data is piped via STDIN.

**Minimum required input:** Either `-message`, `-remove`, or `-list`

**Behavior:**
- Creates a User Notification with:
  - Body text = `-message` value or piped stdin content
  - Title = `-title` (default: "Terminal")
  - Subtitle = `-subtitle` (optional)
- Plays sound if `-sound NAME` specified (`default` or any name from `/System/Library/Sounds`)
- Assigns to a group if `-group ID` specified. Only one notification per group is visible — new posts replace older ones in same group
- Exits immediately after delivery (exit code 0)

#### 3.2 Manage Presentation
- **Custom icon:** `-appIcon URL` — replaces application icon in notification (accepts file or http URL)
- **Attached image:** `-contentImage URL` — shows large image inside notification body
- **Time-sensitive delivery:** `-ignoreDnD` — marks notification as time-sensitive, allowing it to break through Focus modes and notification summaries (macOS 12+). Does not bypass full system Do Not Disturb.

#### 3.3 Define Click Actions
When user clicks the notification, one of two mutually compatible actions can occur (logged to system log via Console.app):

1. **Open resource:** `-open URL` — opens URL (http, file, custom scheme) via NSWorkspace
2. **Execute command:** `-execute COMMAND` — runs shell command via `/bin/sh -c`

#### 3.4 Remove Notifications
**Trigger:** `-remove ID`
- Removes delivered notification belonging to group `ID`
- Special value `ALL` removes all notifications posted by terminal-notifier
- Requires same sender context used when posting

#### 3.5 List Notifications
**Trigger:** `-list ID`
- Returns tab-separated table: `GroupID, Title, Subtitle, Message, Delivered At`
- `ID = ALL` lists all active notifications
- Output format designed for parsing (first line header, subsequent lines data)

#### 3.6 Input Handling
- **Piped input:** If `-message` omitted and stdin is not a TTY, stdin content becomes message body
- **Escaping:** Leading characters that resemble options (e.g., `[`, `-`) must be escaped with backslash (`\[`, ` \-`) to avoid parsing as flags

### 4. Command Interface

```
terminal-notifier -[message|remove|list] [VALUE|ID] [options]
```

**Primary modes (mutually exclusive):**
- `-help` — show usage
- `-version` — show version
- `-message VALUE`
- `-remove ID`
- `-list ID`

**Optional flags:**
- `-title VALUE`
- `-subtitle VALUE`
- `-sound NAME`
- `-group ID`
- `-open URL`
- `-execute COMMAND`
- `-appIcon URL`
- `-contentImage URL`
- `-ignoreDnD`

### 5. Behavioral Rules
1. **Grouping:** Posting with `-group X` automatically removes any prior notification in group X before showing new one
2. **Replacement:** Groups enable status updates (e.g., build progress) without notification spam
3. **Persistence:** Notification lifetime follows system Notification Center settings; tool cannot force "sticky" — user must set Alerts vs Banners in System Preferences
4. **Exit codes:** 0 on success, 1 on failure (e.g., no NotificationCenter, activation failure)
5. **Logging:** Click activation details (group, title, subtitle, message, bundleID, command, open) are written to NSLog

### 6. Non-Goals (explicitly excluded in v2.0)
- Sticky notifications
- Action buttons / reply fields
- Interactive notification responses
These were removed after v1.7 and delegated to separate tool `alerter`

### 7. Example Functional Flows
- **CI build:** `echo "Build passed" | terminal-notifier -group projectX -title "CI" -sound default`
- **Replace previous:** post with same `-group` updates existing banner
- **Click to open:** `-message "Check stocks" -open 'https://finance.yahoo.com/q?s=AAPL'`
- **Click to run:** `-message "Done" -execute 'say "task complete"'`
- **Cleanup:** `-remove ALL`

