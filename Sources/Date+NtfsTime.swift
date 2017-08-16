// Copyright (c) 2017 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

extension Date {

    init?(from ntfsTime: UInt64?) {
        if let time = ntfsTime,
            let ntfsStartDate = DateComponents(calendar: Calendar(identifier: .iso8601),
                                               timeZone: TimeZone(abbreviation: "UTC"),
                                               year: 1601, month: 1,day: 1,
                                               hour: 0, minute: 0, second: 0).date {
            self.init(timeInterval: TimeInterval(time) / 10_000_000, since: ntfsStartDate)
        } else {
            return nil
        }
    }

}
