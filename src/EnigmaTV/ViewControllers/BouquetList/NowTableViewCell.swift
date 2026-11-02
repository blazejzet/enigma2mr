//
//  NowTableViewCell.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 31/05/2020.
//  Copyright © 2020 Blazej Zyglarski. All rights reserved.
//

import UIKit

class NowTableViewCell: UITableViewCell {
    var event:EpgEvent?
    
    @IBOutlet weak var hour: UILabel!
    
    @IBOutlet weak var titlelabel: UILabel!
    
    @IBOutlet weak var duration: UILabel!
    
    @IBOutlet weak var progress: UIProgressView!
    
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations({ self.applyFocusTextColors() }, completion: nil)
    }
    
    
    func setup(e:EpgEvent){
        self.event = e;
        self.titlelabel.text = e.title;
        self.hour.text = e.getBeginTimeString()
        self.duration.text = e.duration_sec == nil ? "" : "\(e.durationMinutes) min."
        self.progress.progress = e.getProgress()
        applyFocusTextColors()
    }

}

extension UITableViewCell {
    /// tvOS look: white text normally, dark text on the white focused cell.
    func applyFocusTextColors() {
        let color: UIColor = isFocused ? UIColor(white: 0.1, alpha: 1) : .white
        var views: [UIView] = [contentView]
        while let v = views.popLast() {
            (v as? UILabel)?.textColor = color
            views.append(contentsOf: v.subviews)
        }
    }
}
