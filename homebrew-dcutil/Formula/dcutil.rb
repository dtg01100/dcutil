class Dcutil < Formula
  desc "Enhanced devcontainer utility with advanced features"
  homepage "https://github.com/dtg01100/dcutil"
  url "https://github.com/dtg01100/dcutil/archive/refs/tags/v1.5.10.tar.gz"
  sha256 "5466b267a2a374e5ff7b3064d0a1c40eb257b8d5aa3bafd91fdc3367a6346f68"
  license "MIT"

  # Dependencies (alphabetical order)
  depends_on "curl"                  # HTTP client for downloading templates/features
  depends_on "devcontainer"          # Official Microsoft devcontainer CLI
  depends_on "docker" => :optional   # Docker container runtime
  depends_on "docker-compose" => :optional  # Docker Compose support
  depends_on "git" => :optional     # Git operations
  depends_on "jq"                    # JSON processing
  depends_on :linux                  # Linux-only for now since we don't have macOS testing
  depends_on "node" => :optional     # Node.js for various agents (opencode, cody, etc.)
  depends_on "python@3.11" => :recommended  # Python 3.11+ for feature management and JSON operations
  depends_on "podman" => :optional   # Podman container runtime
  depends_on "podman-compose" => :optional  # Podman Compose support

  # bottle do
  #   root_url "https://github.com/dtg01100/dcutil/archive/refs/tags/v1.5.10.tar.gz"
  #   sha256 cellar: :any_skip_relocation, arm64_ventura: "UPDATE_WITH_BOTTLE_SHA256"
  #   sha256 cellar: :any_skip_relocation, ventura: "UPDATE_WITH_BOTTLE_SHA256"
  # end

  def install
    # Install the main script
    bin.install "dcutil"

    # Install libraries
    libexec.install Dir["lib/*"]

    # Install completion files
    bash_completion.install "completion.bash" => "dcutil"
    zsh_completion.install "completion.zsh" => "_dcutil"
    fish_completion.install "completion.fish" => "dcutil.fish"

    # Create symlinks for library access
    bin.install_symlink libexec/"core.sh"
    bin.install_symlink libexec/"docker.sh"
    bin.install_symlink libexec/"podman.sh"
    bin.install_symlink libexec/"api_official_cli.sh"
    bin.install_symlink libexec/"volumes.sh"
    bin.install_symlink libexec/"security.sh"
    bin.install_symlink libexec/"init.sh"
    bin.install_symlink libexec/"features.sh"
    bin.install_symlink libexec/"lockfile.sh"
    bin.install_symlink libexec/"lifecycle.sh"
    bin.install_symlink libexec/"environment.sh"
    bin.install_symlink libexec/"userprobe.sh"
    bin.install_symlink libexec/"hostrequirements.sh"
    bin.install_symlink libexec/"shutdown.sh"
    bin.install_symlink libexec/"schema-validation.sh"
    bin.install_symlink libexec/"merging.sh"
    bin.install_symlink libexec/"integration.sh"
    bin.install_symlink libexec/"advanced.sh"
    bin.install_symlink libexec/"build.sh"
    bin.install_symlink libexec/"compose.sh"
  end

  def caveats
    <<~EOS
      dcutil requires a container runtime. Install either Docker or Podman:

        # Docker (Ubuntu/Debian)
        sudo apt-get install docker.io
        sudo systemctl start docker
        sudo usermod -aG docker $USER

        # or Podman
        brew install podman

      For full functionality, consider installing optional dependencies:

        brew install git docker-compose node python@3.11

      Python 3.11+ is required for enhanced feature management (automatically installed if not present):
        brew install python@3.11

      After installation, you may need to install the official devcontainer CLI:

        npm install -g @devcontainers/cli

      For shell completion, restart your shell or run:

        # For bash
        echo 'source $(brew --prefix)/etc/bash_completion.d/dcutil' >> ~/.bashrc

        # For zsh
        echo 'fpath=($(brew --prefix)/share/zsh/site-functions $fpath)' >> ~/.zshrc

        # For fish
        # Completion is automatically installed
    EOS
  end

  test do
    # Basic functionality test
    assert_match "dcutil v#{version}", shell_output("#{bin}/dcutil version")

    # Help command test
    assert_match "Usage: dcutil", shell_output("#{bin}/dcutil help")

    # Test command test
    output = shell_output("#{bin}/dcutil test")
    assert_match "Testing dcutil improvements", output
    assert_match "✅", output
  end
end

