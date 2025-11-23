class Dcutil < Formula
  desc "Devcontainer management tool"
  homepage "https://github.com/dtg01100/dcutil"
  url "https://github.com/dtg01100/dcutil/archive/refs/tags/v1.0.6.tar.gz"
  sha256 "c78a876526898190709e70720100dc076cdfef606070b8e5646184e7814011aa"

  livecheck do
    url :stable
    strategy :github_latest
  end

  def install
    bin.install "dcutil"
  end
end