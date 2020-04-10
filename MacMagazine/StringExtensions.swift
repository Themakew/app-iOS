//
//  StringExtensions.swift
//  MacMagazine
//
//  Created by Cassio Rossi on 27/02/2019.
//  Copyright © 2019 MacMagazine. All rights reserved.
//

import Foundation

enum Format {
	static let wordpress = "EEE, dd MMM yyyy HH:mm:ss +0000"
	static let youtube = "yyyy-MM-dd'T'HH:mm:ss.000'Z'"
}

extension String {

	func toDate() -> Date {
		return toDate(nil)
	}

	func toDate(_ format: String?) -> Date {
        // Expected date format: "Tue, 26 Feb 2019 23:00:53 +0000"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format ?? Format.wordpress
		dateFormatter.locale = Locale(identifier: "en_US")
		dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        return dateFormatter.date(from: self) ?? Date()
    }

    fileprivate func currentCalendar() -> Calendar {
        var calendar = Calendar.current
        if let timeZone = TimeZone(identifier: "America/Sao_Paulo") {
            calendar.timeZone = timeZone
        }
        return calendar
    }

	func toHeaderDate() -> String {
		// Expected date format: "20190227"
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyyMMdd"
		dateFormatter.timeZone = TimeZone(identifier: "America/Sao_Paulo")
		let date = dateFormatter.date(from: self) ?? Date()

		let calendar = currentCalendar()
		if calendar.isDateInToday(date) {
			return "HOJE"
		}
		if calendar.isDateInYesterday(date) {
			return "ONTEM"
		}
		dateFormatter.locale = Locale(identifier: "pt-BR")
		dateFormatter.dateFormat = "EEEE, dd 'DE' MMMM"
		return dateFormatter.string(from: date).uppercased()
	}

	func toComplicationDate() -> String {
		let dateToUse = self.toDate()

        let calendar = currentCalendar()
		let day = String(format: "%02d", calendar.component(.day, from: dateToUse))
		let month = String(format: "%02d", calendar.component(.month, from: dateToUse))
		let hour = String(format: "%02d", calendar.component(.hour, from: dateToUse))
		let minutes = String(format: "%02d", calendar.component(.minute, from: dateToUse))

		if calendar.isDateInToday(dateToUse) {
			return "@\(hour):\(minutes)"
		} else if calendar.isDateInYesterday(dateToUse) {
			return "ONTEM @\(hour):\(minutes)"
		}
		return "\(day)/\(month) @\(hour):\(minutes)"
	}

	func escape() -> String {
		guard let escapedString = self.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) else {
			return ""
		}
		return escapedString
	}

	func toHtmlDecoded() -> String {
		let decoded = try? NSAttributedString(data: Data(utf8), options: [
			.documentType: NSAttributedString.DocumentType.html,
			.characterEncoding: String.Encoding.utf8.rawValue
			], documentAttributes: nil).string

		return decoded ?? self
	}

	func toSubHeaderDate() -> String {
		// Expected date format: "PT4M13S"
		// PT = fixed
		// 4M = 4 minutes
		// 13S = 13 seconds
		let formattedDuration = self
			.replacingOccurrences(of: "PT", with: "")
			.replacingOccurrences(of: "H", with: ":")
			.replacingOccurrences(of: "M", with: ":")
			.replacingOccurrences(of: "S", with: "")

        let components = formattedDuration.components(separatedBy: ":")
        var duration = ""
        for component in components {
            duration = duration.isEmpty ? duration : duration + ":"
            if component.count < 2 {
                duration += "0" + component
                continue
            }
            duration += component
        }

        return duration
	}

}
