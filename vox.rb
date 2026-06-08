cask "vox" do
  version "0.2.11"
  sha256 :no_check  # Will be filled after first release

  url "https://github.com/uicnz/vox/releases/download/v#{version}/Vox-v#{version}.zip"
  name "Vox"
  desc "On-device voice-to-text for macOS"
  homepage "https://github.com/uicnz/vox"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: ">= :sequoia"
  depends_on arch: :arm64

  app "Vox.app"

  zap trash: [
    "~/Library/Application Support/nz.uic.vox",
    "~/Library/Caches/nz.uic.vox",
    "~/Library/Containers/nz.uic.vox",
    "~/Library/Preferences/nz.uic.vox.plist",
  ]
end
