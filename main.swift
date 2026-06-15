import Foundation
import UserNotifications
import AppKit

// MARK: - Stderr Utility
func printError(_ message: String) {
    fputs(message + "\n", Darwin.stderr)
}

// MARK: - Attachment Helper
func createAttachment(from urlString: String, identifier: String) async -> UNNotificationAttachment? {
    if urlString.isEmpty { return nil }
    
    let fileManager = FileManager.default
    let tempDir = fileManager.temporaryDirectory
    
    do {
        let sourceURL: URL
        let isRemote: Bool
        
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            guard let url = URL(string: urlString) else { return nil }
            sourceURL = url
            isRemote = true
        } else {
            if urlString.hasPrefix("file://") {
                guard let url = URL(string: urlString) else { return nil }
                sourceURL = url
            } else {
                sourceURL = URL(fileURLWithPath: urlString)
            }
            isRemote = false
        }
        
        let pathExtension = sourceURL.pathExtension.isEmpty ? "tmp" : sourceURL.pathExtension
        let destURL = tempDir.appendingPathComponent("\(identifier)_\(UUID().uuidString).\(pathExtension)")
        
        if isRemote {
            let (tempURL, _) = try await URLSession.shared.download(from: sourceURL)
            if fileManager.fileExists(atPath: destURL.path) {
                try fileManager.removeItem(at: destURL)
            }
            try fileManager.moveItem(at: tempURL, to: destURL)
        } else {
            if fileManager.fileExists(atPath: destURL.path) {
                try fileManager.removeItem(at: destURL)
            }
            try fileManager.copyItem(at: sourceURL, to: destURL)
        }
        
        let attachment = try UNNotificationAttachment(identifier: identifier, url: destURL, options: nil)
        return attachment
    } catch {
        printError("Error: Failed to create attachment for \(urlString): \(error)")
        return nil
    }
}

// MARK: - Action Handler
func handleNotificationClick(userInfo: [AnyHashable: Any]) {
    NSLog("[terminal-notifier] Notification clicked with userInfo: \(userInfo)")
    
    if let openURLStr = userInfo["open"] as? String, let url = URL(string: openURLStr) {
        NSLog("[terminal-notifier] Opening URL: \(openURLStr)")
        NSWorkspace.shared.open(url)
    }
    
    if let execute = userInfo["execute"] as? String {
        NSLog("[terminal-notifier] Executing command: \(execute)")
        let process = Process()
        process.launchPath = "/bin/sh"
        process.arguments = ["-c", execute]
        do {
            try process.run()
        } catch {
            NSLog("[terminal-notifier] Failed to execute command: \(error)")
        }
    }
}

// MARK: - Application Delegate
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        
        if let userInfo = notification.userInfo,
           userInfo[NSApplication.launchUserNotificationUserInfoKey] != nil {
            // Wait up to 3 seconds for the notification response callback to execute
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                exit(0)
            }
        } else {
            exit(0)
        }
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        handleNotificationClick(userInfo: userInfo)
        completionHandler()
        exit(0)
    }
}

// MARK: - Notification Request Wrapper
func addNotificationRequest(_ request: UNNotificationRequest) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: ())
            }
        }
    }
}

// MARK: - Main Execution Block

var message: String?
var removeID: String?
var listID: String?
var title: String = "Terminal"
var subtitle: String?
var sound: String?
var group: String?
var openURL: String?
var execute: String?
var appIcon: String?
var contentImage: String?
var ignoreDnD = false
var showHelp = false
var showVersion = false
var listSounds = false

func unescape(_ value: String) -> String {
    if value.hasPrefix("\\-") {
        return String(value.dropFirst())
    }
    if value.hasPrefix("\\[") {
        return String(value.dropFirst())
    }
    return value
}

func readStdin() -> String? {
    guard isatty(STDIN_FILENO) == 0 else { return nil }
    var input = ""
    while let line = readLine(strippingNewline: false) {
        input += line
    }
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

let helpMessage = """
Usage: terminal-notifier -[message|remove|list] [VALUE|ID] [options]

Primary modes (mutually exclusive):
  -help             Show this help message
  -version          Show version
  -message VALUE    Post a notification with the specified message
  -remove ID        Remove delivered notification belonging to group ID (or ALL)
  -list ID          List delivered notifications (ID can be ALL)
  -list-sounds      List available system and user sound names

Optional flags:
  -title VALUE      Title (default: "Terminal")
  -subtitle VALUE   Subtitle
  -sound NAME       Play sound (e.g. "default", or files in /System/Library/Sounds)
  -group ID         Group notification ID. Replaces prior notification in same group
  -open URL         URL to open when clicked
  -execute COMMAND  Shell command to execute when clicked
  -appIcon URL      URL (local or http) of custom icon for notification
  -contentImage URL URL (local or http) of large image in notification body
  -ignoreDnD        Mark as time-sensitive (bypasses Focus modes & summaries, macOS 12+)
"""

func listAvailableSounds() {
    let fileManager = FileManager.default
    var soundNames: Set<String> = []
    
    let soundDirs = [
        "/System/Library/Sounds",
        "/Library/Sounds",
        NSHomeDirectory() + "/Library/Sounds"
    ]
    
    for dir in soundDirs {
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: dir, isDirectory: &isDir), isDir.boolValue {
            do {
                let files = try fileManager.contentsOfDirectory(atPath: dir)
                for file in files {
                    let ext = (file as NSString).pathExtension.lowercased()
                    if ["aif", "aiff", "wav", "caf", "mp3", "m4a", "m4r"].contains(ext) {
                        let name = (file as NSString).deletingPathExtension
                        soundNames.insert(name)
                    }
                }
            } catch {
                // Ignore read errors for inaccessible folders
            }
        }
    }
    
    let sortedNames = soundNames.sorted()
    if sortedNames.isEmpty {
        print("No system or user sounds found.")
    } else {
        print("Available sounds:")
        for name in sortedNames {
            print("  \(name)")
        }
    }
}

func parseArguments() {
    let args = CommandLine.arguments.dropFirst()
    var iterator = args.makeIterator()
    
    while let arg = iterator.next() {
        switch arg {
        case "-help", "-h", "--help":
            showHelp = true
        case "-version", "-v", "--version":
            showVersion = true
        case "-list-sounds":
            listSounds = true
        case "-message":
            message = iterator.next()
        case "-remove":
            removeID = iterator.next()
        case "-list":
            listID = iterator.next()
        case "-title":
            title = iterator.next() ?? "Terminal"
        case "-subtitle":
            subtitle = iterator.next()
        case "-sound":
            sound = iterator.next()
        case "-group":
            group = iterator.next()
        case "-open":
            openURL = iterator.next()
        case "-execute":
            execute = iterator.next()
        case "-appIcon":
            appIcon = iterator.next()
        case "-contentImage":
            contentImage = iterator.next()
        case "-ignoreDnD":
            ignoreDnD = true
        default:
            printError("Unknown option: \(arg)")
        }
    }
}

func getDeliveredNotifications() async -> [UNNotification] {
    await withCheckedContinuation { continuation in
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            continuation.resume(returning: notifications)
        }
    }
}

parseArguments()

let isCLI = CommandLine.arguments.count > 1 || isatty(STDIN_FILENO) == 0

if isCLI {
    if showHelp {
        print(helpMessage)
        exit(0)
    }
    
    if showVersion {
        print("2.0.0")
        exit(0)
    }
    
    if listSounds {
        listAvailableSounds()
        exit(0)
    }
    
    let center = UNUserNotificationCenter.current()
    
    if let removeID = removeID {
        if removeID == "ALL" {
            center.removeAllDeliveredNotifications()
            print("Removed all notifications.")
        } else {
            center.removeDeliveredNotifications(withIdentifiers: [removeID])
            print("Removed notification group: \(removeID)")
        }
        exit(0)
    }
    
    if let listID = listID {
        let notifications = await getDeliveredNotifications()
        print("GroupID\tTitle\tSubtitle\tMessage\tDelivered At")
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        
        for notification in notifications {
            let req = notification.request
            let content = req.content
            let userInfo = content.userInfo
            
            let group = userInfo["group"] as? String ?? req.identifier
            
            if listID != "ALL" && group != listID {
                continue
            }
            
            let title = content.title
            let subtitle = content.subtitle
            let message = content.body
            let dateStr = formatter.string(from: notification.date)
            
            print("\(group)\t\(title)\t\(subtitle)\t\(message)\t\(dateStr)")
        }
        exit(0)
    }
    
    var msgBody = message
    if msgBody == nil {
        msgBody = readStdin()
    }
    
    guard let body = msgBody, !body.isEmpty else {
        printError("Error: A message must be specified (via -message or stdin), or use -remove or -list.")
        printError(helpMessage)
        exit(1)
    }
    
    let cleanTitle = unescape(title)
    let cleanSubtitle = subtitle.map { unescape($0) }
    let cleanBody = unescape(body)
    
    let settings = await center.notificationSettings()
    if settings.authorizationStatus == .notDetermined {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            if !granted {
                printError("Error: Notification authorization denied.")
                exit(1)
            }
        } catch {
            printError("Error: Failed to request notification authorization: \(error)")
            exit(1)
        }
    } else if settings.authorizationStatus == .denied {
        printError("Error: Notification authorization is denied in System Settings.")
        exit(1)
    }
    
    let content = UNMutableNotificationContent()
    content.title = cleanTitle
    if let sub = cleanSubtitle {
        content.subtitle = sub
    }
    content.body = cleanBody
    
    if let soundName = sound {
        if soundName == "default" {
            content.sound = .default
        } else {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundName))
        }
    }
    
    var userInfo: [AnyHashable: Any] = [:]
    if let openURL = openURL { userInfo["open"] = openURL }
    if let execute = execute { userInfo["execute"] = execute }
    if let group = group { userInfo["group"] = group }
    content.userInfo = userInfo
    
    var attachments: [UNNotificationAttachment] = []
    if let appIcon = appIcon {
        if let att = await createAttachment(from: appIcon, identifier: "appIcon") {
            attachments.append(att)
        }
    }
    if let contentImage = contentImage {
        if let att = await createAttachment(from: contentImage, identifier: "contentImage") {
            attachments.append(att)
        }
    }
    content.attachments = attachments
    
    let identifier = group ?? UUID().uuidString
    
    if group != nil {
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
    
    if ignoreDnD {
        if #available(macOS 12.0, *) {
            content.interruptionLevel = .timeSensitive
        }
    }
    
    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
    
    do {
        try await addNotificationRequest(request)
        // Give the OS a small moment to queue and process
        try await Task.sleep(nanoseconds: 100_000_000)
        exit(0)
    } catch {
        printError("Error: Failed to post notification: \(error)")
        exit(1)
    }
} else {
    let delegate = AppDelegate()
    UNUserNotificationCenter.current().delegate = delegate
    let app = NSApplication.shared
    app.delegate = delegate
    app.run()
}
