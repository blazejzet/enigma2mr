//
//  BouquetCell.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 16.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import UIKit
import CloudKit

class MovieCell: CommonTableViewCell {
    var service:Movie?
    var del:MoviesViewController?
    
    
    @IBOutlet weak var progress_bar: UIImageView!
    
    @IBOutlet weak var serviceLabel: UILabel!
    @IBOutlet weak var detailsLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var recordingLabel: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    func configure(serv:Movie, ck:CKRecord?){
        super.conf()
        self.isUserInteractionEnabled=true
        self.service = serv;
        self.serviceLabel.text = serv.servicename
        self.detailsLabel.text = serv.filesize_readable
        self.recordingLabel.text = serv.eventname
        self.dateLabel.text = serv.begintime
        //self.timeLabel.text = "\(serv.recordingtime!/60) min"
        let tinm = serv.lengthSeconds / 60
        self.timeLabel.text = serv.length
        self.recordingLabel.text = "⚪️   \(serv.eventname ?? "")"
        self.setInidicatorFrame(x: 0.0)
        self.backdrop=nil
        self.picon=nil
        //self.backgroundColor = UIColor.clear
        self.requestImage(name: serv.eventname ?? "", tinm: tinm, servicename: serv.servicename ?? "")
        if let ck = ck{
            self.recordingLabel.text = "🔵   \(serv.eventname ?? "")"
            let n = ck["watched"] as? NSNumber
            let s = Double((n?.intValue ?? 0) * 2)
            let f = self.progress_bar.frame
            self.progress_bar.frame =
                CGRect(x: f.origin.x, y: f.origin.y, width: CGFloat(s), height: f.size.height)
        }else{
            if let pb = self.progress_bar{
                    let f = pb.frame;
                pb.frame =
                    CGRect(x: f.origin.x, y: f.origin.y, width: 0.0, height: f.size.height)
            }
        }
        
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    override func deleteItem(){
        guard let movie = self.service else { return }
        STBAPI.common()?.movieDelete(movie) { [weak self] _, _ in
            self?.del?.reload()
        }
    }
    
    
}
