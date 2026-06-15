class TerminalNotifier < Formula
  desc "Post native macOS User Notifications from the command-line"
  homepage "https://github.com/iman1704/terminal-notifier"
  url "file:///Users/mohamadiman/Documents/Projects/terminal-notifier"
  version "0.0.1"
  # Since it's a local file URL, we can use a dummy SHA or omit it
  # sha256 "..."

  def install
    # Build the application bundle using our build script
    system "./build.sh", version.to_s

    # Install the app bundle under the Homebrew libexec folder
    libexec.install "terminal-notifier.app"

    # Symlink the bundle's internal binary to Homebrew's bin folder
    bin.install_symlink libexec/"terminal-notifier.app/Contents/MacOS/terminal-notifier" => "terminal-notifier"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/terminal-notifier -version")
  end
end
