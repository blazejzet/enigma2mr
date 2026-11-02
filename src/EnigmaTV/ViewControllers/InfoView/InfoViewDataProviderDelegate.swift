//
//  InfoViewDataProvider.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 25.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import UIKit

protocol InfoViewDataProviderDelegate {

    func getCurrentEvent()->EpgEvent?
    func getNextEvent()->EpgEvent?
    func getCurrentTime()->UInt64
    func getRealTime()->UInt64
    func getTimeshiftStartTime()->UInt64
    func getTimeshiftStopTime()->UInt64
    func shouldDisplayTimeshiftInfo()->Bool
    func getServiceName()->String
    func jumpTo(_ time:UInt64)
}
