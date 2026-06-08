# typed: strict
# frozen_string_literal: true

cask "aria-vox" do
  version "0.1.2,02"
  sha256 "75ac63ce9a18e71b7a30b5a66b23a69c9188d0d7c98020606fc8e0cfe68a1bd4"

  url "https://github.com/uicnz/vox/releases/download/v#{version.csv.first}/" \
      "Vox-#{version.csv.first}-#{version.csv.second}.zip?download=1"
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
