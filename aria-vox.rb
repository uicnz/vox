# typed: strict
# frozen_string_literal: true

cask "aria-vox" do
  version "0.1.0,01"
  sha256 "feffb11a793ea3a4b6bc8e5b9e446f46df2ef044dd63a086f98ebe5e692a3998"

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
