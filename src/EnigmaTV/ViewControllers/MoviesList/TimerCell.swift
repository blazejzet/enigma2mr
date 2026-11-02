//
//  BouquetCell.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 16.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import UIKit
import CloudKit

class TimerCell: CommonTableViewCell {
    var service:RecordingTimer?
    var del:MoviesViewController?
    
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var serviceLabel: UILabel!
    @IBOutlet weak var detailsLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var recordingLabel: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    func configure(serv:RecordingTimer){
        super.conf();
        self.isUserInteractionEnabled=true
        self.service = serv;
        self.serviceLabel.text = serv.servicename
        self.detailsLabel.text = ""
        self.recordingLabel.text = serv.name
        self.dateLabel.text = serv.realbegin
        self.backdrop=nil
        self.picon=nil
        //self.timeLabel.text = "\(serv.recordingtime!/60) min"
        
        self.requestImage(name: serv.name ?? "", tinm: (serv.duration ?? 0) / 60, servicename: serv.servicename ?? "")
        self.setInidicatorFrame(x: 0.0)
        self.recordingLabel.text = "🔴   \(serv.name ?? "")"
        
        //self.backgroundColor = UIColor.clear
        
        
        
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
    override func deleteItem(){
        guard let timer = self.service else { return }
        STBAPI.common()?.timerDelete(timer) { [weak self] _, _ in
            self?.del?.reload()
        }
    }
    
    
    
}
