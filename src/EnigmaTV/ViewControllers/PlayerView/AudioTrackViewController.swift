//
//  AudioTrackViewController.swift
//  EnigmaTV
//
//  Created by Damian Skarżyński on 09/01/2020.
//  Copyright © 2020 Blazej Zyglarski. All rights reserved.
//

import UIKit
import AVKit

class AudioTrackViewController: UIViewController, UITableViewDelegate, UITableViewDataSource  {
    
    
    
    @IBOutlet weak var audioTracksTable: UITableView!
    @IBOutlet weak var subtitlesTable: UITableView!
    @IBOutlet weak var audioDestinationView: UIView!
    //    @IBOutlet weak var audioDestinationTable: UITableView!
    
    weak var sv:StreamView? {
        didSet{
            //zostało ustawione
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        audioTracksTable.dataSource = self
        audioTracksTable.delegate = self
        audioTracksTable.register(UITableViewCell.self, forCellReuseIdentifier: "audioTracksCell")
        
        subtitlesTable.dataSource = self
        subtitlesTable.delegate = self
        subtitlesTable.register(UITableViewCell.self, forCellReuseIdentifier: "subtitlesCell")
        
        //        sv?.mp?.currentAudioTrackIndex = 0
        
        //        audioDestinationView = AVRoutePickerView()
        
        let AirPlayButton = AVRoutePickerView(frame: CGRect(x: 1600, y: 220, width: 66, height: 66))
        
//        AirPlayButton.docus
        view.addSubview(AirPlayButton)
        
        //        let AirPlayButton = AVRoutePickerView()
        //        audioDestinationView.addSubview(AirPlayButton)
        
        print("AudioTrackVC - ")
        print("AudioTrackVC - subtitleTracksNames : \(sv?.mp?.videoSubTitlesNames)")
        
        print("AudioTrackVC - audioTracksNames : \(sv?.mp?.audioTrackNames)")
        print("AudioTrackVC - audioTracksIndexes : \(sv?.mp?.audioTrackIndexes)")
        print("AudioTrackVC - currentAudioTrackIndex: \(sv?.mp?.currentAudioTrackIndex)")
        // Do any additional setup after loading the view.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
    }
    
    
    /// Tracks as shown in the tables. VLC replaces its track arrays when the stream reconnects, so the
    /// rows work on this snapshot and a selection is checked against the current tracks before use.
    private typealias Track = (index: Int32, name: String)
    private var audioTracks = [Track]()
    private var subtitleTracks = [Track]()

    private static func tracks(indexes: [Any]?, names: [Any]?) -> [Track] {
        guard let indexes = indexes, let names = names else { return [] }
        return zip(indexes, names).compactMap { index, name in
            guard let index = (index as? NSNumber)?.int32Value else { return nil }
            return (index, name as? String ?? "\(index)")
        }
    }


    private func tracks(for tableView: UITableView) -> [Track] {
        return tableView == audioTracksTable ? audioTracks : tableView == subtitlesTable ? subtitleTracks : []
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let mp = sv?.mp
        if tableView == audioTracksTable {
            audioTracks = AudioTrackViewController.tracks(indexes: mp?.audioTrackIndexes, names: mp?.audioTrackNames)
        } else if tableView == subtitlesTable {
            subtitleTracks = AudioTrackViewController.tracks(indexes: mp?.videoSubTitlesIndexes, names: mp?.videoSubTitlesNames)
        }
        // One explanatory row instead of an empty column.
        return max(tracks(for: tableView).count, 1)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let identifier = tableView == subtitlesTable ? "subtitlesCell" : "audioTracksCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
        let list = tracks(for: tableView)
        guard indexPath.row < list.count else {
            cell.textLabel?.text = tableView == subtitlesTable ? "No subtitles" : "Default audio"
            cell.textLabel?.font = cell.textLabel?.font.withSize(30)
            return cell
        }
        let track = list[indexPath.row]
        let current = tableView == subtitlesTable ? sv?.mp?.currentVideoSubTitleIndex : sv?.mp?.currentAudioTrackIndex
        cell.textLabel?.text = track.index == current ? "✔️ \(track.name)" : track.name
        cell.textLabel?.font = cell.textLabel?.font.withSize(30)
        return cell
    }
    
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let list = tracks(for: tableView)
        if indexPath.row < list.count, let mp = sv?.mp {
            let index = list[indexPath.row].index
            switch tableView {
            case audioTracksTable:
                print("AudioTrackVC - audio track \(index)")
                if (mp.audioTrackIndexes as? [NSNumber])?.contains(where: { $0.int32Value == index }) == true {
                    mp.currentAudioTrackIndex = index
                }
            case subtitlesTable:
                print("AudioTrackVC - subtitle track \(index)")
                if (mp.videoSubTitlesIndexes as? [NSNumber])?.contains(where: { $0.int32Value == index }) == true {
                    mp.currentVideoSubTitleIndex = index
                }
            default:
                break
            }
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
        tableView.reloadData()
    }
    
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 66
    }
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destination.
     // Pass the selected object to the new view controller.
     }
     */
    
}
