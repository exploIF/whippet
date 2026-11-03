import Foundation

/// Built-in cleanup rules.
///
/// Project rules are matched in order. The first rule that matches a directory wins,
/// so more specific rules come before generic ones (e.g. Gradle `build` before JS `build`).
enum RuleCatalog {
    static let all: [CleanupRule] = xcode + android + reactNative + javascript + packageManagers

    static func rule(id: String) -> CleanupRule? { all.first { $0.id == id } }

    // MARK: - Xcode & Swift

    static let xcode: [CleanupRule] = [
        CleanupRule(
            id: "xcode.derivedData",
            category: .xcode,
            name: "Xcode DerivedData",
            location: .global("~/Library/Developer/Xcode/DerivedData"),
            risk: .safe,
            summary: "Intermediate build products, indexes and logs for every project Xcode has built.",
            regenerateHint: "Rebuilt on the next build; the first build and indexing will be slower."
        ),
        CleanupRule(
            id: "xcode.archives",
            category: .xcode,
            name: "Xcode Archives",
            location: .global("~/Library/Developer/Xcode/Archives"),
            risk: .caution,
            summary: "Archived app builds, including the dSYM files needed to symbolicate crash reports for released versions.",
            regenerateHint: "Can't be regenerated exactly. Keep archives for builds you shipped."
        ),
        CleanupRule(
            id: "xcode.iosDeviceSupport",
            category: .xcode,
            name: "iOS DeviceSupport",
            location: .global("~/Library/Developer/Xcode/iOS DeviceSupport"),
            risk: .moderate,
            summary: "Debug symbols copied from each physical iOS device and OS version you've connected.",
            regenerateHint: "Copied again from the device the next time you connect it, which takes several minutes."
        ),
        CleanupRule(
            id: "xcode.watchosDeviceSupport",
            category: .xcode,
            name: "watchOS DeviceSupport",
            location: .global("~/Library/Developer/Xcode/watchOS DeviceSupport"),
            risk: .moderate,
            summary: "Debug symbols copied from paired Apple Watch devices.",
            regenerateHint: "Copied again from the watch the next time you debug on it."
        ),
        CleanupRule(
            id: "xcode.simulatorCaches",
            category: .xcode,
            name: "Simulator caches",
            location: .global("~/Library/Developer/CoreSimulator/Caches"),
            risk: .safe,
            summary: "Cached data for iOS simulators, such as dyld shared caches.",
            regenerateHint: "Rebuilt when a simulator boots; the first boot will be slower."
        ),
        CleanupRule(
            id: "xcode.previews",
            category: .xcode,
            name: "SwiftUI Previews",
            location: .global("~/Library/Developer/Xcode/UserData/Previews"),
            risk: .safe,
            summary: "Simulator devices and build products used to render SwiftUI previews.",
            regenerateHint: "Recreated the next time a preview is shown."
        ),
        CleanupRule(
            id: "xcode.swiftpmCache",
            category: .xcode,
            name: "Swift Package Manager cache",
            location: .global("~/Library/Caches/org.swift.swiftpm"),
            risk: .safe,
            summary: "Downloaded copies of Swift package repositories shared across projects.",
            regenerateHint: "Packages are downloaded again on the next package resolve."
        ),
        CleanupRule(
            id: "xcode.projectBuild",
            category: .xcode,
            name: "Xcode project build folder",
            location: .project(ArtifactPattern(directoryName: "build", markers: ["*.xcodeproj", "*.xcworkspace"])),
            risk: .safe,
            summary: "Build output written next to an Xcode project, e.g. by xcodebuild or React Native's iOS build.",
            regenerateHint: "Rebuilt on the next build."
        ),
        CleanupRule(
            id: "xcode.swiftpmBuild",
            category: .xcode,
            name: "Swift package .build",
            location: .project(ArtifactPattern(directoryName: ".build", markers: ["Package.swift"])),
            risk: .safe,
            summary: "Build output and checked-out dependencies of a Swift package.",
            regenerateHint: "Rebuilt by `swift build`; dependencies are fetched again."
        ),
    ]

    // MARK: - Android & Gradle

    static let android: [CleanupRule] = [
        CleanupRule(
            id: "android.gradleCaches",
            category: .android,
            name: "Gradle caches",
            location: .global("~/.gradle/caches"),
            risk: .moderate,
            summary: "Downloaded dependencies, transformed artifacts and the build cache shared by all Gradle projects.",
            regenerateHint: "Dependencies are downloaded again on the next build, which can take a long time."
        ),
        CleanupRule(
            id: "android.gradleWrapper",
            category: .android,
            name: "Gradle wrapper distributions",
            location: .global("~/.gradle/wrapper/dists"),
            risk: .moderate,
            summary: "Every Gradle version downloaded by a project's gradlew wrapper.",
            regenerateHint: "Each project downloads its Gradle version again the next time it builds."
        ),
        CleanupRule(
            id: "android.sdkCache",
            category: .android,
            name: "Android SDK cache",
            location: .global("~/.android/cache"),
            risk: .safe,
            summary: "Temporary downloads and metadata cached by Android SDK tools.",
            regenerateHint: "Recreated by the SDK tools when needed."
        ),
        CleanupRule(
            id: "android.moduleBuild",
            category: .android,
            name: "Gradle module build folder",
            location: .project(ArtifactPattern(directoryName: "build", markers: ["build.gradle", "build.gradle.kts"])),
            risk: .safe,
            summary: "Compiled classes, APKs and intermediates of a Gradle module (e.g. android/app/build).",
            regenerateHint: "Rebuilt on the next Gradle build."
        ),
        CleanupRule(
            id: "android.projectGradle",
            category: .android,
            name: "Project .gradle folder",
            location: .project(ArtifactPattern(directoryName: ".gradle", markers: ["settings.gradle", "settings.gradle.kts", "gradlew"])),
            risk: .safe,
            summary: "Per-project Gradle state such as file hashes and configuration cache.",
            regenerateHint: "Recreated on the next Gradle build."
        ),
        CleanupRule(
            id: "android.cxx",
            category: .android,
            name: "Native build (.cxx)",
            location: .project(ArtifactPattern(directoryName: ".cxx", markers: ["build.gradle", "build.gradle.kts"])),
            risk: .safe,
            summary: "CMake/NDK intermediate files for native C++ code, common in React Native apps.",
            regenerateHint: "Rebuilt on the next build; native compilation takes a while."
        ),
    ]

    // MARK: - React Native & CocoaPods

    static let reactNative: [CleanupRule] = [
        CleanupRule(
            id: "rn.pods",
            category: .reactNative,
            name: "CocoaPods Pods folder",
            location: .project(ArtifactPattern(directoryName: "Pods", markers: ["Podfile"])),
            risk: .moderate,
            summary: "Installed CocoaPods dependencies for an iOS project (e.g. ios/Pods in React Native).",
            regenerateHint: "Run `pod install` (or `npx pod-install`) before the next iOS build."
        ),
        CleanupRule(
            id: "rn.cocoapodsCache",
            category: .reactNative,
            name: "CocoaPods cache",
            location: .global("~/Library/Caches/CocoaPods"),
            risk: .safe,
            summary: "Downloaded pod sources and specs shared across projects.",
            regenerateHint: "Pods are downloaded again on the next `pod install`."
        ),
        CleanupRule(
            id: "rn.metroCache",
            category: .reactNative,
            name: "Metro bundler cache",
            location: .global("$TMPDIR/metro-*"),
            risk: .safe,
            summary: "Transformed JavaScript cached by the Metro bundler.",
            regenerateHint: "Rebuilt the next time Metro bundles; the first bundle is slower."
        ),
        CleanupRule(
            id: "rn.hasteMap",
            category: .reactNative,
            name: "Haste map cache",
            location: .global("$TMPDIR/haste-map-*"),
            risk: .safe,
            summary: "File maps cached by Metro and Jest.",
            regenerateHint: "Rebuilt on the next Metro or Jest run."
        ),
        CleanupRule(
            id: "rn.expo",
            category: .reactNative,
            name: "Expo project cache",
            location: .project(ArtifactPattern(directoryName: ".expo", markers: ["package.json"])),
            risk: .safe,
            summary: "Local Expo CLI state and generated type files for an Expo project.",
            regenerateHint: "Recreated by the Expo CLI on the next start."
        ),
    ]

    // MARK: - JavaScript & Web

    static let javascript: [CleanupRule] = [
        CleanupRule(
            id: "js.nodeModules",
            category: .javascript,
            name: "node_modules",
            location: .project(ArtifactPattern(directoryName: "node_modules", markers: ["package.json"])),
            risk: .moderate,
            summary: "Installed npm packages for a JavaScript project.",
            regenerateHint: "Run `npm install` / `yarn` / `pnpm install` before working on the project again."
        ),
        cacheDir(id: "js.next", name: "Next.js cache (.next)", dir: ".next", what: "Next.js build output and cache."),
        cacheDir(id: "js.nuxt", name: "Nuxt cache (.nuxt)", dir: ".nuxt", what: "Generated Nuxt build files."),
        cacheDir(id: "js.turbo", name: "Turborepo cache (.turbo)", dir: ".turbo", what: "Local Turborepo task cache."),
        cacheDir(id: "js.parcel", name: "Parcel cache", dir: ".parcel-cache", what: "Parcel bundler cache."),
        cacheDir(id: "js.svelteKit", name: "SvelteKit output (.svelte-kit)", dir: ".svelte-kit", what: "Generated SvelteKit build files."),
        CleanupRule(
            id: "js.angularCache",
            category: .javascript,
            name: "Angular CLI cache",
            location: .project(ArtifactPattern(directoryName: "cache", intermediatePath: [".angular"], markers: ["angular.json"])),
            risk: .safe,
            summary: "Angular CLI build cache.",
            regenerateHint: "Rebuilt on the next `ng build` or `ng serve`."
        ),
        CleanupRule(
            id: "js.dist",
            category: .javascript,
            name: "dist folder",
            location: .project(ArtifactPattern(directoryName: "dist", markers: ["package.json"])),
            risk: .moderate,
            summary: "Build output of a JavaScript project. Some projects commit or publish this folder.",
            regenerateHint: "Run the project's build script again.",
            isEnabledByDefault: false
        ),
        CleanupRule(
            id: "js.build",
            category: .javascript,
            name: "build folder",
            location: .project(ArtifactPattern(directoryName: "build", markers: ["package.json"])),
            risk: .moderate,
            summary: "Build output of a JavaScript project. Some projects commit or publish this folder.",
            regenerateHint: "Run the project's build script again.",
            isEnabledByDefault: false
        ),
    ]

    // MARK: - Package manager caches

    static let packageManagers: [CleanupRule] = [
        CleanupRule(
            id: "pm.npm",
            category: .packageManagers,
            name: "npm cache",
            location: .global("~/.npm/_cacache"),
            risk: .safe,
            summary: "Downloaded npm package tarballs and metadata.",
            regenerateHint: "Packages are downloaded again on the next install, so offline installs won't work until then."
        ),
        CleanupRule(
            id: "pm.yarn",
            category: .packageManagers,
            name: "Yarn cache",
            location: .global("~/Library/Caches/Yarn"),
            risk: .safe,
            summary: "Downloaded packages cached by Yarn.",
            regenerateHint: "Packages are downloaded again on the next `yarn install`."
        ),
        CleanupRule(
            id: "pm.pnpm",
            category: .packageManagers,
            name: "pnpm store",
            location: .global("~/Library/pnpm/store"),
            risk: .moderate,
            summary: "pnpm's content-addressable store. Projects hard-link packages from here, so the real space freed may be smaller than shown.",
            regenerateHint: "Packages are downloaded again on the next `pnpm install`."
        ),
        CleanupRule(
            id: "pm.bun",
            category: .packageManagers,
            name: "Bun cache",
            location: .global("~/.bun/install/cache"),
            risk: .safe,
            summary: "Downloaded packages cached by Bun.",
            regenerateHint: "Packages are downloaded again on the next `bun install`."
        ),
        CleanupRule(
            id: "pm.homebrew",
            category: .packageManagers,
            name: "Homebrew downloads",
            location: .global("~/Library/Caches/Homebrew"),
            risk: .safe,
            summary: "Downloaded bottles and source archives kept after installing Homebrew packages.",
            regenerateHint: "Downloaded again only if you reinstall a package."
        ),
    ]

    private static func cacheDir(id: String, name: String, dir: String, what: String) -> CleanupRule {
        CleanupRule(
            id: id,
            category: .javascript,
            name: name,
            location: .project(ArtifactPattern(directoryName: dir, markers: ["package.json"])),
            risk: .safe,
            summary: what,
            regenerateHint: "Rebuilt on the next dev server start or build."
        )
    }
}
