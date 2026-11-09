import Foundation

public enum PresentationPrivacyRule {
    /// Resolves manual and automatic settings against display state; returns a reason, or nil when visible.
    public static func reason(manual: Bool, mirrored: Bool, external: Bool, settings: WorkSettings) -> String? {
        if manual { return "手动演示隐私" }
        if settings.hideMenuBarWhenMirroring && mirrored { return "检测到屏幕镜像" }
        if settings.hideWhenExternalDisplay && external { return "检测到外接显示器" }
        return nil
    }
}
