class Dcutil < Formula
  desc "Enhanced devcontainer utility with advanced features"
  homepage "https://github.com/dtg01100/dcutil"
  url "https://github.com/dtg01100/dcutil/archive/refs/tags/v1.0.8.tar.gz"
  sha256 "CHECKSUM_WILL_BE_AUTO_UPDATED_ON_RELEASE"
  license "MIT"

  # Linux-only for now since we don't have macOS testing
  depends_on :linux

  # bottle do
  #   root_url "https://github.com/dtg01100/homebrew-dcutil/releases/download/dcutil-1.0.8"
  #   sha256 cellar: :any_skip_relocation, arm64_ventura: "UPDATE_WITH_BOTTLE_SHA256"
  #   sha256 cellar: :any_skip_relocation, ventura: "UPDATE_WITH_BOTTLE_SHA256"
  # end

  # Required dependencies
  depends_on "jq"                    # JSON processing
  depends_on "devcontainer"          # Official Microsoft devcontainer CLI
  depends_on "curl"                  # HTTP client for downloading templates/features
  depends_on "python@3.11"           # Fallback JSON processing and agent support

  # Container runtime (one of these is required)
  depends_on "docker" => :optional   # Docker container runtime
  depends_on "podman" => :optional   # Podman container runtime

  # Optional dependencies for enhanced features
  depends_on "git" => :optional      # Git operations
  depends_on "docker-compose" => :optional  # Docker Compose support
  depends_on "podman-compose" => :optional  # Podman Compose support

  # Node.js for various agents (opencode, cody, etc.)
  depends_on "node" => :optional

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

        brew install git docker-compose node

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