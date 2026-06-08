# typed: strict
# frozen_string_literal: true

cask "aria-vox" do
  version "0.1.0,01"
  sha256 "cfcdd6665271d25a90bf7a461008f5a81642bb54a56752ee9b90c5e1f6259175"

  url "https://github.com/uicnz/vox/releases/download/v#{version.csv.first}/" \
      "Vox-#{version.csv.first}-#{version.csv.second}.zip"
  name "Vox"
  desc "On-device voice-to-text"
  homepage "https://github.com/uicnz/vox"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: :sequoia
  depends_on arch: :arm64

  app "Vox.app"

  zap trash: [
    "~/Library/Application Support/nz.uic.vox",
    "~/Library/Caches/nz.uic.vox",
    "~/Library/Containers/nz.uic.vox",
    "~/Library/Preferences/nz.uic.vox.plist",
  ]
end
