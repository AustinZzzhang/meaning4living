import AppKit
import Sparkle

final class UpdateHarness: NSObject, SPUUserDriver, SPUUpdaterDelegate {
    var updater: SPUUpdater!
    let feed: String
    let mode: String

    /// Creates a fixture driver using feed and expected mode; returns a harness confined to the test host.
    init(feed: String, mode: String) {
        self.feed = feed
        self.mode = mode
    }

    /// Supplies the local fixture URL for updater; returns the feed string.
    func feedURLString(for updater: SPUUpdater) -> String? { feed }

    /// Answers permission request without enabling automatic checks; replies once and returns nothing.
    func show(
        _ request: SPUUpdatePermissionRequest,
        reply: @escaping (SUUpdatePermissionResponse) -> Void
    ) {
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: false, sendSystemProfile: false))
    }

    /// Records a check start; cancellation is unused because the fixture has a timeout, returns nothing.
    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) { print("CHECK") }

    /// Accepts appcastItem/state only for this disposable fixture via reply; returns nothing.
    func showUpdateFound(
        with appcastItem: SUAppcastItem,
        state: SPUUserUpdateState,
        reply: @escaping (SPUUserUpdateChoice) -> Void
    ) {
        print("FOUND \(appcastItem.versionString)")
        reply(.install)
    }

    /// Ignores downloaded notes data in the noninteractive fixture; returns nothing.
    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}

    /// Fails when release note download reports error; returns nothing.
    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {
        fputs("NOTES \(error)\n", stderr)
    }

    /// Treats no update as a fixture failure; acknowledges error and exits nonzero, returns nothing.
    func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        acknowledgement()
        finish(error: error)
    }

    /// Records a rejected update; acknowledges error and exits according to expected test mode, returns nothing.
    func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        acknowledgement()
        finish(error: error)
    }

    /// Records download start; cancellation remains unused, returns nothing.
    func showDownloadInitiated(cancellation: @escaping () -> Void) { print("DOWNLOAD") }

    /// Records expectedContentLength from the server; returns nothing.
    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        print("SIZE \(expectedContentLength)")
    }

    /// Ignores intermediate length increments; returns nothing.
    func showDownloadDidReceiveData(ofLength length: UInt64) {}

    /// Records that the archive passed download validation and is extracting; no parameters or return value.
    func showDownloadDidStartExtractingUpdate() { print("EXTRACT") }

    /// Ignores intermediate extraction progress; returns nothing.
    func showExtractionReceivedProgress(_ progress: Double) {}

    /// Installs the disposable fixture by replying install; returns nothing.
    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) { reply(.install) }

    /// Records termination state without retrying the unused handler; returns nothing.
    func showInstallingUpdate(
        withApplicationTerminated applicationTerminated: Bool,
        retryTerminatingApplication: @escaping () -> Void
    ) {
        print("INSTALL \(applicationTerminated)")
    }

    /// Acknowledges successful installation/relaunched state and exits; returns nothing.
    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        acknowledgement()
        print("INSTALLED")
        exit(mode == "install" ? 0 : 1)
    }

    /// Does nothing when Sparkle dismisses its internal UI; no parameters or return value.
    func dismissUpdateInstallation() {}

    /// Reports error; rejection mode expects a cryptographic validation failure, returns nothing before exit.
    private func finish(error: Error) {
        let value = error as NSError
        print("REJECTED \(value.domain) \(value.code) \(value.localizedDescription)")
        print(value.userInfo)
        var current: NSError? = value
        var signatureFailure = false
        while let error = current {
            if error.domain == SUSparkleErrorDomain && [3001, 3002].contains(error.code) {
                signatureFailure = true
            }
            current = error.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        exit(mode == "reject" && signatureFailure ? 0 : 1)
    }
}

let application = NSApplication.shared
application.setActivationPolicy(.prohibited)
if CommandLine.arguments.count == 1 {
    print("Fixture relaunched after installation")
    exit(0)
}
let fixture = URL(fileURLWithPath: CommandLine.arguments[1])
let fixturePrefix = URL(fileURLWithPath: CommandLine.arguments[4]).standardizedFileURL.path + "/"
guard fixture.standardizedFileURL.path.hasPrefix(fixturePrefix),
      CommandLine.arguments[2].hasPrefix("http://127.0.0.1:"),
      let bundle = Bundle(url: fixture),
      bundle.bundleIdentifier?.hasPrefix("local.livingmeaning.update-fixture.") == true else {
    fatalError("Refusing a target outside the disposable local update fixture")
}
let harness = UpdateHarness(feed: CommandLine.arguments[2], mode: CommandLine.arguments[3])
harness.updater = SPUUpdater(
    hostBundle: bundle,
    applicationBundle: Bundle.main,
    userDriver: harness,
    delegate: harness
)
harness.updater.automaticallyChecksForUpdates = false
DispatchQueue.main.async {
    do {
        try harness.updater.start()
        harness.updater.checkForUpdates()
    } catch {
        fputs("START \(error)\n", stderr)
        exit(1)
    }
}
DispatchQueue.main.asyncAfter(deadline: .now() + 55) {
    fputs("Fixture timed out\n", stderr)
    exit(1)
}
application.run()
