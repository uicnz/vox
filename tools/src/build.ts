#!/usr/bin/env bun

import {
  chmodSync,
  copyFileSync,
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { basename, dirname, join, resolve } from "node:path";

type Options = {
  clean: boolean;
  configuration: string;
  derivedDataPath: string;
  githubDraft: boolean;
  githubPrerelease: boolean;
  githubReleaseTag: string;
  githubRepo: string;
  githubSparkleReleaseTag: string;
  install: boolean;
  maximumDeltas: number;
  notaryProfile: string;
  publishGithub: boolean;
  signIdentity: string;
  skipAppcast: boolean;
  skipBuild: boolean;
  skipGithubVersionRelease: boolean;
  skipNotarize: boolean;
  sparkleEdKeyFile?: string;
  updatesDir: string;
  verbose: boolean;
};

const root = resolve(import.meta.dirname, "../..");
const packageJson = JSON.parse(readFileSync(join(root, "package.json"), "utf8")) as {
  version: string;
};

const defaults = {
  configuration: "Release",
  githubSparkleReleaseTag: "sparkle",
  notaryProfile: "aria-notarytool",
  signIdentity: "Developer ID Application: Shane Holloman (N68C9LUA5B)",
};

function parseArgs(argv: string[]): Options {
  const versionTag = `v${packageJson.version}`;
  const options: Options = {
    clean: false,
    configuration: defaults.configuration,
    derivedDataPath: join(root, ".derivedData", "release"),
    githubDraft: false,
    githubPrerelease: false,
    githubReleaseTag: process.env.GITHUB_RELEASE_TAG ?? versionTag,
    githubRepo: process.env.GITHUB_REPOSITORY ?? inferGithubRepo() ?? "uicnz/vox",
    githubSparkleReleaseTag:
      process.env.GITHUB_SPARKLE_RELEASE_TAG ?? defaults.githubSparkleReleaseTag,
    install: false,
    maximumDeltas: Number.parseInt(process.env.SPARKLE_MAXIMUM_DELTAS ?? "3", 10),
    notaryProfile: defaults.notaryProfile,
    publishGithub: false,
    signIdentity: defaults.signIdentity,
    skipAppcast: false,
    skipBuild: false,
    skipGithubVersionRelease: false,
    skipNotarize: false,
    sparkleEdKeyFile: process.env.SPARKLE_ED_KEY_FILE,
    updatesDir: join(root, "build", "updates"),
    verbose: false,
  };

  for (const arg of argv) {
    if (arg === "--help" || arg === "-h") {
      printHelp();
      process.exit(0);
    } else if (arg === "--clean") {
      options.clean = true;
    } else if (arg === "--install") {
      options.install = true;
    } else if (arg === "--publish-github") {
      options.publishGithub = true;
    } else if (arg === "--github-draft") {
      options.githubDraft = true;
    } else if (arg === "--github-prerelease") {
      options.githubPrerelease = true;
    } else if (arg === "--skip-build") {
      options.skipBuild = true;
    } else if (arg === "--skip-appcast") {
      options.skipAppcast = true;
    } else if (arg === "--skip-github-version-release") {
      options.skipGithubVersionRelease = true;
    } else if (arg === "--skip-notarize") {
      options.skipNotarize = true;
    } else if (arg === "--verbose") {
      options.verbose = true;
    } else if (arg.startsWith("--configuration=")) {
      options.configuration = valueFor(arg);
    } else if (arg.startsWith("--derived-data=")) {
      options.derivedDataPath = resolve(root, valueFor(arg));
    } else if (arg.startsWith("--github-release-tag=")) {
      options.githubReleaseTag = valueFor(arg);
    } else if (arg.startsWith("--github-repo=")) {
      options.githubRepo = valueFor(arg);
    } else if (arg.startsWith("--github-sparkle-release-tag=")) {
      options.githubSparkleReleaseTag = valueFor(arg);
    } else if (arg.startsWith("--maximum-deltas=")) {
      options.maximumDeltas = Number.parseInt(valueFor(arg), 10);
    } else if (arg.startsWith("--notary-profile=")) {
      options.notaryProfile = valueFor(arg);
    } else if (arg.startsWith("--sign-identity=")) {
      options.signIdentity = valueFor(arg);
    } else if (arg.startsWith("--sparkle-ed-key-file=")) {
      options.sparkleEdKeyFile = resolve(root, valueFor(arg));
    } else if (arg.startsWith("--updates-dir=")) {
      options.updatesDir = resolve(root, valueFor(arg));
    } else {
      throw new Error(`Unknown option: ${arg}`);
    }
  }

  if (!Number.isFinite(options.maximumDeltas) || options.maximumDeltas < 0) {
    throw new Error("--maximum-deltas must be a non-negative integer");
  }

  return options;
}

function valueFor(arg: string): string {
  const value = arg.slice(arg.indexOf("=") + 1);
  if (!value) throw new Error(`Missing value for ${arg}`);
  return value;
}

function printHelp(): void {
  console.log(`Vox signed build

Usage:
  bun run tools/src/build.ts [options]

Options:
  --install                         Copy the verified app to /Applications/Vox.app
  --publish-github                  Publish release assets to GitHub Releases
  --github-repo=<owner/repo>        GitHub repository (default: remote origin, GITHUB_REPOSITORY, or uicnz/vox)
  --github-release-tag=<tag>        User-facing GitHub release tag (default: v${packageJson.version})
  --github-sparkle-release-tag=<tag> Dedicated Sparkle artifact release tag (default: sparkle)
  --github-draft                    Create the user-facing release as a draft
  --github-prerelease               Mark the user-facing release as a prerelease
  --updates-dir=<path>              Sparkle archive directory (default: build/updates)
  --maximum-deltas=<count>          Delta updates to generate for the latest version (default: 3)
  --sparkle-ed-key-file=<path>      Sparkle EdDSA private key file for appcast signing
  --skip-appcast                    Publish GitHub assets without regenerating appcast.xml
  --skip-github-version-release     Only update the dedicated Sparkle artifact release
  --skip-notarize                   Build and Developer ID sign, but do not notarize
  --skip-build                      Reuse the existing app in the derived data path
  --clean                           Remove the derived data path before building
  --configuration=<name>            Xcode configuration (default: Release)
  --derived-data=<path>             Xcode DerivedData path (default: .derivedData/release)
  --sign-identity=<identity>        Code signing identity
  --notary-profile=<profile>        notarytool keychain profile (default: aria-notarytool)
  --verbose                         Print command lines before running them
  --help                            Show this help
`);
}

function appPath(options: Options): string {
  return join(
    options.derivedDataPath,
    "Build",
    "Products",
    options.configuration,
    "Vox.app"
  );
}

function appEntitlementsPath(options: Options): string {
  return join(
    options.derivedDataPath,
    "Build",
    "Intermediates.noindex",
    "Vox.build",
    options.configuration,
    "Vox.build",
    "Vox.app.xcent"
  );
}

function artifactZipPath(options: Options): string {
  const build = readBundleVersion(appPath(options));
  const artifactsDir = join(root, "build", "artifacts");
  mkdirSync(artifactsDir, { recursive: true });
  return join(artifactsDir, `Vox-${packageJson.version}-${build}.zip`);
}

function artifactDmgPath(options: Options): string {
  const build = readBundleVersion(appPath(options));
  const artifactsDir = join(root, "build", "artifacts");
  mkdirSync(artifactsDir, { recursive: true });
  return join(artifactsDir, `Vox-${packageJson.version}-${build}.dmg`);
}

async function main(): Promise<void> {
  const options = parseArgs(process.argv.slice(2));
  const app = appPath(options);
  const entitlements = appEntitlementsPath(options);
  let zipPath: string | undefined;

  logHeader("Vox Build");
  logInfo(`Version: ${packageJson.version}`);
  logInfo(`Configuration: ${options.configuration}`);
  logInfo(`DerivedData: ${options.derivedDataPath}`);
  logInfo(`Signing: ${options.signIdentity}`);
  logInfo(`Notary profile: ${options.skipNotarize ? "skipped" : options.notaryProfile}`);

  if (options.clean) {
    step("Cleaning derived data");
    rmSync(options.derivedDataPath, { recursive: true, force: true });
    ok("Derived data removed");
  }

  if (!options.skipBuild) {
    step("Building Vox.app");
    await run(
      [
        "xcodebuild",
        "-scheme",
        "Vox",
        "-configuration",
        options.configuration,
        "-derivedDataPath",
        options.derivedDataPath,
        "-skipMacroValidation",
        "-quiet",
        "build",
        "CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO",
      ],
      options
    );
    ok("Xcode build complete");
  }

  requirePath(app, "Built app");
  requirePath(entitlements, "Generated app entitlements");

  await signEmbeddedCode(app, options);

  step("Signing Vox.app");
  await run(
    [
      "codesign",
      "--force",
      "--sign",
      options.signIdentity,
      "--options",
      "runtime",
      "--entitlements",
      entitlements,
      "--timestamp",
      app,
    ],
    options
  );
  ok("Vox.app signed");

  await verifyApp(app, options, false);

  if (!options.skipNotarize) {
    zipPath = await createZipArtifact(app, options, "Creating notarization archive");

    step("Submitting to Apple notarization");
    await run(
      [
        "xcrun",
        "notarytool",
        "submit",
        zipPath,
        "--keychain-profile",
        options.notaryProfile,
        "--wait",
      ],
      options
    );
    ok("Apple notarization accepted");

    step("Stapling notarization ticket");
    await run(["xcrun", "stapler", "staple", app], options);
    await run(["xcrun", "stapler", "validate", app], options);
    ok("Notarization ticket stapled");

    await verifyApp(app, options, true);

    zipPath = await createZipArtifact(app, options, "Creating release ZIP with stapled app");
  }

  if (options.publishGithub) {
    zipPath ??= await createZipArtifact(app, options, "Creating release ZIP");
    const dmgPath = await createDmgArtifact(app, options);

    if (!options.skipNotarize) {
      await notarizeDmg(dmgPath, options);
    }

    await publishToGithub({ dmgPath, zipPath }, options);
  }

  if (options.install) {
    await installApp(app, options);
  }

  ok(`Done: ${app}`);
}

async function createZipArtifact(
  app: string,
  options: Options,
  label: string
): Promise<string> {
  const zipPath = artifactZipPath(options);
  step(label);
  rmSync(zipPath, { force: true });
  await run(["ditto", "-c", "-k", "--keepParent", app, zipPath], options);
  ok(`Created ${zipPath}`);
  return zipPath;
}

async function createDmgArtifact(app: string, options: Options): Promise<string> {
  const dmgPath = artifactDmgPath(options);
  step("Creating release DMG");
  rmSync(dmgPath, { force: true });
  await run(
    ["hdiutil", "create", "-volname", "Vox", "-srcfolder", app, "-ov", "-format", "UDZO", dmgPath],
    options
  );
  ok(`Created ${dmgPath}`);
  return dmgPath;
}

async function notarizeDmg(dmgPath: string, options: Options): Promise<void> {
  step("Submitting DMG to Apple notarization");
  await run(
    [
      "xcrun",
      "notarytool",
      "submit",
      dmgPath,
      "--keychain-profile",
      options.notaryProfile,
      "--wait",
    ],
    options
  );
  ok("DMG notarization accepted");

  step("Stapling DMG notarization ticket");
  await run(["xcrun", "stapler", "staple", dmgPath], options);
  await run(["xcrun", "stapler", "validate", dmgPath], options);
  ok("DMG notarization ticket stapled");
}

async function signEmbeddedCode(app: string, options: Options): Promise<void> {
  const frameworksDir = join(app, "Contents", "Frameworks");
  if (existsSync(frameworksDir)) {
    for (const entry of readdirSync(frameworksDir, { withFileTypes: true })) {
      const fullPath = join(frameworksDir, entry.name);
      if (!entry.isDirectory()) continue;
      if (!entry.name.endsWith(".framework") && !entry.name.endsWith(".app")) continue;

      step(`Signing embedded ${entry.name}`);
      await run(
        [
          "codesign",
          "--force",
          "--deep",
          "--sign",
          options.signIdentity,
          "--options",
          "runtime",
          "--timestamp",
          fullPath,
        ],
        options
      );
      ok(`${entry.name} signed`);
    }
  }

  const pluginsDir = join(app, "Contents", "PlugIns");
  if (existsSync(pluginsDir)) {
    for (const entry of readdirSync(pluginsDir, { withFileTypes: true })) {
      if (!entry.isDirectory()) continue;
      const fullPath = join(pluginsDir, entry.name);
      step(`Signing plugin ${entry.name}`);
      await run(
        [
          "codesign",
          "--force",
          "--deep",
          "--sign",
          options.signIdentity,
          "--options",
          "runtime",
          "--timestamp",
          fullPath,
        ],
        options
      );
      ok(`${entry.name} signed`);
    }
  }
}

async function verifyApp(app: string, options: Options, requireGatekeeper: boolean): Promise<void> {
  step("Verifying deep code signature");
  await run(["codesign", "--verify", "--strict", "--deep", "--verbose=4", app], options);
  ok("Code signature verified");

  if (requireGatekeeper) {
    step("Running Gatekeeper assessment");
    await run(["spctl", "-a", "-vvv", "-t", "exec", app], options);
    ok("Gatekeeper accepts app");
  }
}

async function installApp(app: string, options: Options): Promise<void> {
  const destination = "/Applications/Vox.app";

  step("Quitting installed Vox if running");
  await run(["osascript", "-e", 'tell application id "nz.uic.vox" to quit'], {
    ...options,
    allowFailure: true,
  });
  await sleep(1500);
  ok("Install target is ready");

  step(`Installing to ${destination}`);
  await run(["rsync", "-a", "--delete", `${app}/`, `${destination}/`], options);
  ok("Installed app copied");

  step("Verifying installed app");
  await run(["codesign", "--verify", "--strict", "--deep", "--verbose=4", destination], options);
  if (!options.skipNotarize) {
    await run(["xcrun", "stapler", "validate", destination], options);
    await run(["spctl", "-a", "-vvv", "-t", "exec", destination], options);
  }
  ok("Installed app verified");
}

async function publishToGithub(
  artifacts: { dmgPath: string; zipPath: string },
  options: Options
): Promise<void> {
  step("Preparing Sparkle update assets");
  mkdirSync(options.updatesDir, { recursive: true });
  rmSync(join(options.updatesDir, "vox-latest.dmg"), { force: true });

  const updateDmgPath = join(options.updatesDir, basename(artifacts.dmgPath));
  copyFileSync(artifacts.dmgPath, updateDmgPath);

  const latestDmgPath = join(root, "build", "artifacts", "vox-latest.dmg");
  copyFileSync(artifacts.dmgPath, latestDmgPath);
  ok(`Prepared ${updateDmgPath}`);

  if (!options.skipAppcast) {
    await generateAppcast(options);
  }

  await ensureGithubRelease(
    options.githubSparkleReleaseTag,
    "Vox Sparkle Updates",
    ["--notes", "Stable Sparkle appcast and latest Vox DMG assets."],
    options
  );

  const sparkleAssets = [...sparkleAssetsIn(options.updatesDir), latestDmgPath];
  await uploadGithubAssets(options.githubSparkleReleaseTag, sparkleAssets, options);
  ok(`Sparkle feed: ${githubSparkleFeedURL(options)}`);

  if (!options.skipGithubVersionRelease) {
    await ensureGithubRelease(
      options.githubReleaseTag,
      `Vox ${packageJson.version}`,
      ["--generate-notes"],
      options
    );

    await uploadGithubAssets(
      options.githubReleaseTag,
      [artifacts.dmgPath, artifacts.zipPath],
      options
    );
  }
}

async function generateAppcast(options: Options): Promise<void> {
  const keyMaterial = materializeSparklePrivateKey(options);
  const args = [
    join(root, "bin", "generate_appcast"),
    "--download-url-prefix",
    githubSparkleDownloadPrefix(options),
    "--link",
    `https://github.com/${options.githubRepo}/releases/tag/${options.githubReleaseTag}`,
    "--maximum-deltas",
    String(options.maximumDeltas),
  ];

  if (keyMaterial.path) {
    args.push("--ed-key-file", keyMaterial.path);
  }

  args.push(options.updatesDir);

  try {
    step("Generating Sparkle appcast");
    await run(args, options);
    ok(`Generated ${join(options.updatesDir, "appcast.xml")}`);
  } finally {
    keyMaterial.cleanup?.();
  }
}

function materializeSparklePrivateKey(options: Options): {
  path?: string;
  cleanup?: () => void;
} {
  if (options.sparkleEdKeyFile) return { path: options.sparkleEdKeyFile };

  const privateKey = process.env.SPARKLE_PRIVATE_KEY ?? process.env.SPARKLE_ED_PRIVATE_KEY;
  if (!privateKey) return {};

  const keyPath = join(options.derivedDataPath, "sparkle-ed-private-key");
  mkdirSync(dirname(keyPath), { recursive: true });
  writeFileSync(keyPath, `${privateKey.trim()}\n`, { mode: 0o600 });
  chmodSync(keyPath, 0o600);

  return {
    path: keyPath,
    cleanup: () => rmSync(keyPath, { force: true }),
  };
}

function sparkleAssetsIn(updatesDir: string): string[] {
  return readdirSync(updatesDir)
    .filter(name => {
      if (name === "vox-latest.dmg") return false;
      return (
        name === "appcast.xml" ||
        name.endsWith(".dmg") ||
        name.endsWith(".delta") ||
        name.endsWith(".tar") ||
        name.endsWith(".tbz") ||
        name.endsWith(".zip")
      );
    })
    .map(name => join(updatesDir, name));
}

async function ensureGithubRelease(
  tag: string,
  title: string,
  notesArgs: string[],
  options: Options
): Promise<void> {
  if (
    await commandSucceeds(["gh", "release", "view", tag, "--repo", options.githubRepo], options)
  ) {
    return;
  }

  const args = [
    "gh",
    "release",
    "create",
    tag,
    "--repo",
    options.githubRepo,
    "--title",
    title,
    ...notesArgs,
  ];
  if (tag === options.githubReleaseTag) {
    if (options.githubDraft) args.push("--draft");
    if (options.githubPrerelease) args.push("--prerelease");
  }

  step(`Creating GitHub release ${tag}`);
  await run(args, options);
  ok(`GitHub release ${tag} exists`);
}

async function uploadGithubAssets(tag: string, paths: string[], options: Options): Promise<void> {
  if (paths.length === 0) return;

  step(`Uploading ${paths.length} asset(s) to GitHub release ${tag}`);
  await run(
    ["gh", "release", "upload", tag, ...paths, "--repo", options.githubRepo, "--clobber"],
    options
  );
  ok(`Uploaded assets to ${tag}`);
}

async function commandSucceeds(args: string[], options: Options): Promise<boolean> {
  if (options.verbose) {
    logInfo(`$ ${args.map(quoteArg).join(" ")}`);
  }

  const proc = Bun.spawn(args, {
    cwd: root,
    stderr: "pipe",
    stdout: "pipe",
  });
  return (await proc.exited) === 0;
}

function githubSparkleDownloadPrefix(options: Options): string {
  return `https://github.com/${options.githubRepo}/releases/download/${encodeURIComponent(
    options.githubSparkleReleaseTag
  )}/`;
}

function githubSparkleFeedURL(options: Options): string {
  return `${githubSparkleDownloadPrefix(options)}appcast.xml`;
}

function inferGithubRepo(): string | undefined {
  const remote = Bun.spawnSync(["git", "config", "--get", "remote.origin.url"], {
    cwd: root,
    stderr: "pipe",
    stdout: "pipe",
  });

  if (remote.exitCode !== 0) return undefined;

  const remoteURL = remote.stdout.toString().trim();
  return parseGithubRepo(remoteURL);
}

function parseGithubRepo(remoteURL: string): string | undefined {
  const sshMatch = /^git@github\.com:([^/]+\/[^/]+?)(?:\.git)?$/.exec(remoteURL);
  if (sshMatch?.[1]) return sshMatch[1];

  const httpsMatch = /^https:\/\/github\.com\/([^/]+\/[^/]+?)(?:\.git)?$/.exec(remoteURL);
  if (httpsMatch?.[1]) return httpsMatch[1];

  return undefined;
}

function readBundleVersion(app: string): string {
  const infoPath = join(app, "Contents", "Info.plist");
  requirePath(infoPath, "Info.plist");
  const plist = Bun.spawnSync(["plutil", "-extract", "CFBundleVersion", "raw", infoPath], {
    cwd: root,
    stdout: "pipe",
    stderr: "pipe",
  });
  if (plist.exitCode !== 0) {
    throw new Error(`Could not read CFBundleVersion from ${infoPath}`);
  }
  return plist.stdout.toString().trim();
}

function requirePath(path: string, label: string): void {
  if (!existsSync(path)) {
    throw new Error(`${label} not found: ${path}`);
  }
  statSync(path);
}

type RunOptions = Options & { allowFailure?: boolean };

async function run(args: string[], options: RunOptions): Promise<void> {
  if (options.verbose) {
    logInfo(`$ ${args.map(quoteArg).join(" ")}`);
  }

  const proc = Bun.spawn(args, {
    cwd: root,
    stderr: "inherit",
    stdout: "inherit",
  });
  const exitCode = await proc.exited;
  if (exitCode !== 0 && !options.allowFailure) {
    throw new Error(`Command failed (${exitCode}): ${args.map(quoteArg).join(" ")}`);
  }
}

function quoteArg(arg: string): string {
  if (/^[A-Za-z0-9_./:=+-]+$/.test(arg)) return arg;
  return JSON.stringify(arg);
}

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function logHeader(label: string): void {
  console.log(`\n== ${label} ==`);
}

function step(label: string): void {
  console.log(`\n> ${label}`);
}

function ok(label: string): void {
  console.log(`[ok] ${label}`);
}

function logInfo(label: string): void {
  console.log(`- ${label}`);
}

main().catch(error => {
  console.error(`\n[error] ${error instanceof Error ? error.message : String(error)}`);
  process.exit(1);
});
