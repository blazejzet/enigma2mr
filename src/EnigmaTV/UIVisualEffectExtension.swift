//
//  UIVisualEffectExtension.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 18/11/2019.
//  Copyright © 2019 Blazej Zyglarski. All rights reserved.
//

import UIKit
import CoreImage

/// `-EnigmaBlur YES`: blurs the live video and all third-party artwork (TMDB posters/backdrops),
/// so App Review screenshots and the demo video do not show copyrighted broadcasts.
enum ReviewBlur {
    static let enabled = UserDefaults.standard.bool(forKey: "EnigmaBlur")
    private static let context = CIContext()

    /// Heavily blurred copy of `image` (unchanged when the flag is off).
    static func image(_ image: UIImage?) -> UIImage? {
        guard enabled, let image = image, let input = CIImage(image: image) else { return image }
        let sigma = max(input.extent.width, input.extent.height) * 0.05
        let output = input.clampedToExtent().applyingGaussianBlur(sigma: Double(sigma)).cropped(to: input.extent)
        guard let cg = context.createCGImage(output, from: output.extent) else { return image }
        return UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
    }

    /// Frosted overlay that hides what is rendered below it (used over the VLC drawables).
    static func overlay() -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
        view.isUserInteractionEnabled = false
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return view
    }
}

/// VLC drawable that keeps a `ReviewBlur` overlay above the video layer VLC inserts.
final class VideoDrawableView: UIView {
    private var blur: UIVisualEffectView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        if ReviewBlur.enabled {
            let blur = ReviewBlur.overlay()
            blur.frame = bounds
            addSubview(blur)
            self.blur = blur
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateBlur()
    }

    override func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)
        updateBlur()
    }

    override func willRemoveSubview(_ subview: UIView) {
        super.willRemoveSubview(subview)
        DispatchQueue.main.async { self.updateBlur() }
    }

    /// VLC inserts its video view only while a video output exists – without it the
    /// overlay would show as an empty frosted rectangle (e.g. the idle PiP drawable).
    private func updateBlur() {
        guard let blur = blur else { return }
        blur.frame = bounds
        blur.isHidden = !subviews.contains { $0 !== blur }
        bringSubview(toFront: blur)
    }
}

/// Shared look: Liquid Glass on tvOS 26+, dark blur before.
enum Glass {
    static let cornerRadius: CGFloat = 40
    static let margin: CGFloat = 80          // tvOS safe area inset
    static let primaryText = UIColor.white
    static let secondaryText = UIColor(white: 1, alpha: 0.65)
    static let accent = UIColor(red: 0.04, green: 0.52, blue: 1, alpha: 1)

    static func effect(interactive: Bool = false) -> UIVisualEffect {
        if #available(tvOS 26.0, *) {
            let glass = UIGlassEffect(style: .regular)
            glass.isInteractive = interactive
            return glass
        }
        return UIBlurEffect(style: .dark)
    }

    /// Rounded glass panel; put content into `contentView`.
    static func panel(cornerRadius: CGFloat = Glass.cornerRadius, interactive: Bool = false) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: effect(interactive: interactive))
        view.layer.cornerRadius = cornerRadius
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    static func label(_ style: UIFont.TextStyle, weight: UIFont.Weight = .regular, color: UIColor = Glass.primaryText) -> UILabel {
        let label = UILabel()
        let size = UIFont.preferredFont(forTextStyle: style).pointSize
        label.font = UIFont.systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
}

/// Rounded panel used in the storyboard – rendered as Liquid Glass.
class UIVisualEffectExtension : UIVisualEffectView {

    override init(effect: UIVisualEffect?) {
        super.init(effect: effect)
        style()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        effect = Glass.effect()
        style()
    }

    private func style() {
        layer.cornerRadius = Glass.cornerRadius
        layer.cornerCurve = .continuous
        clipsToBounds = true
    }
}
