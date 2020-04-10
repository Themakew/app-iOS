//
//  SettingsTableViewController.swift
//  MacMagazine
//
//  Created by Cassio Rossi on 27/02/2019.
//  Copyright © 2019 MacMagazine. All rights reserved.
//

import CoreSpotlight
import Kingfisher
import MessageUI
import UIKit

class SettingsTableViewController: UITableViewController {

    // MARK: - Properties -

    @IBOutlet private weak var fontSize: UISlider!
    @IBOutlet private weak var reportProblem: AppTableViewCell!

	@IBOutlet private weak var iconOption1: UIImageView!
	@IBOutlet private weak var iconOption2: UIImageView!
    @IBOutlet private weak var iconOption3: UIImageView!

	@IBOutlet private weak var pushOptions: AppSegmentedControl!

    @IBOutlet private weak var darkModeSegmentControl: AppSegmentedControl!

    var version: String = ""

    // MARK: - View lifecycle -

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.backgroundColor = Settings().theme.backgroundColor

        version = getAppVersion()

        let sliderFontSize = Settings().fontSize
        fontSize.value = sliderFontSize == "fontemenor" ? 0.0 : sliderFontSize == "fontemaior" ? 2.0 : 1.0

		let iconName = UserDefaults.standard.string(forKey: Definitions.icon)
		self.iconOption1.alpha = iconName ?? IconOptions.option1 == IconOptions.option1 ? 1 : 0.6
		self.iconOption2.alpha = iconName ?? IconOptions.option1 == IconOptions.option2 ? 1 : 0.6
        self.iconOption3.alpha = iconName ?? IconOptions.option1 == IconOptions.option3 ? 1 : 0.6

		pushOptions.selectedSegmentIndex = Settings().pushPreference

        guard MFMailComposeViewController.canSendMail() else {
			reportProblem.isHidden = true
			return
		}
    }

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

        if !Settings().supportsNativeDarkMode {
            darkModeSegmentControl.removeSegment(at: 2, animated: false)
        }

        guard let delegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        delegate.supportedInterfaceOrientation = Settings().orientations

        applyTheme()
	}

	// MARK: - TableView Methods -

    fileprivate func getHeaders() -> [String] {
        var header = ["MACMAGAZINE \(version)", "RECEBER PUSHES PARA", "TAMANHO DA FONTE"]
        header.append("APARÊNCIA")
        header.append("ÍCONE DO APLICATIVO")
        header.append("")

        return header
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let header = getHeaders()
        if header.isEmpty ||
            (header.count - 1) < section ||
            header[section] == "" {
            return nil
        }
		return header[section]
    }

    // MARK: - View Methods -

	@IBAction private func clearCache(_ sender: Any) {
		// Delete all posts and podcasts
		CoreDataStack.shared.flush()

		// Delete all downloaded images
		ImageCache.default.clearDiskCache()

		// Clean Spotlight search indexes
		CSSearchableIndex.default().deleteAllSearchableItems(completionHandler: nil)

		// Feedback message
		let alertController = UIAlertController(title: "Cache limpo!", message: "Todo o conteúdo do app será agora recarregado.", preferredStyle: .alert)
		alertController.addAction(UIAlertAction(title: "OK", style: .default) { _ in
			self.dismiss(animated: true)
		})
		if Settings().isDarkMode {
			alertController.view.tintColor = LightTheme().tint
		}
		self.present(alertController, animated: true)
	}

    @IBAction private func changeFontSize(_ sender: Any) {
        guard let slider = sender as? UISlider else {
            return
        }

        var fontSize = ""
        var roundedValue = 1

		if slider.value < 0.65 {
            roundedValue = 0
            fontSize = "fontemenor"
        }
        if slider.value > 1.4 {
            roundedValue = 2
            fontSize = "fontemaior"
        }
        slider.value = Float(roundedValue)

        UserDefaults.standard.set(fontSize, forKey: Definitions.fontSize)
        UserDefaults.standard.synchronize()

		applyTheme()
    }

    @IBAction private func changeDarkMode(_ sender: Any) {
        guard let darkMode = sender as? UISegmentedControl else {
            return
        }
        UserDefaults.standard.set(darkMode.selectedSegmentIndex, forKey: Definitions.darkMode)
        UserDefaults.standard.synchronize()

        applyTheme()
	}

	@IBAction private func setPushMode(_ sender: Any) {
		guard let segment = sender as? AppSegmentedControl else {
			return
		}
		Settings().updatePushPreference(segment.selectedSegmentIndex)
    }

	// MARK: - Private Methods -

    fileprivate func applyTheme() {
        Settings().applyTheme()
        darkModeSegmentControl.selectedSegmentIndex = Settings().appearance.rawValue
        tableView.backgroundColor = Settings().theme.backgroundColor
    }

}

// MARK: - App Icon Methods -

extension SettingsTableViewController {

	struct IconOptions {
		static let option1 = "option_1"
		static let option2 = "option_2"
        static let option3 = "option_3"
        static let type = Settings().isPhone ? "phone" : "tablet"
        static let icon1 = "\(type)_1"
        static let icon2 = "\(type)_2"
        static let icon3 = "\(type)_3"

		func getIcon(for option: String) -> String? {
			var icon: String?

			switch option {
			case IconOptions.option1:
				icon = IconOptions.icon1
			case IconOptions.option2:
				icon = IconOptions.icon2
            case IconOptions.option3:
                icon = IconOptions.icon3
			default:
				break
			}

			return icon
		}
	}

	@IBAction private func changeAppIcon(_ sender: Any) {
		guard let button = sender as? UIButton,
			let option = button.restorationIdentifier else {
				return
		}
		changeIcon(to: option)
	}

	fileprivate func changeIcon(to iconName: String) {
		guard UIApplication.shared.supportsAlternateIcons,
			let icon = IconOptions().getIcon(for: iconName) else {
				return
		}

		// Temporary change the colors
		if Settings().isDarkMode {
			UIApplication.shared.keyWindow?.tintColor = LightTheme().tint
		}

		UIApplication.shared.setAlternateIconName(icon) { error in
			if error == nil {
				// Return to theme settings
				DispatchQueue.main.async {
					self.applyTheme()
				}

				UserDefaults.standard.set(iconName, forKey: Definitions.icon)
				UserDefaults.standard.synchronize()

				self.iconOption1.alpha = iconName == IconOptions.option1 ? 1 : 0.6
				self.iconOption2.alpha = iconName == IconOptions.option2 ? 1 : 0.6
                self.iconOption3.alpha = iconName == IconOptions.option3 ? 1 : 0.6
			}
		}
	}

}

// MARK: - Mail Methods -

extension SettingsTableViewController: MFMailComposeViewControllerDelegate {

	@IBAction private func reportProblem(_ sender: Any) {
		let composeVC = MFMailComposeViewController()
		composeVC.mailComposeDelegate = self
		composeVC.setSubject("Relato de problema no app MacMagazine \(version)")
		composeVC.setToRecipients(["contato@macmagazine.com.br"])

		// Temporary change the colors
		Settings().applyLightTheme()

		self.present(composeVC, animated: true, completion: nil)
	}

	public func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
		controller.dismiss(animated: true) {
			Settings().applyDarkTheme()
		}
	}

	fileprivate func getAppVersion() -> String {
		let bundle = Bundle(for: type(of: self))
		let appVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String
		return "\(appVersion ?? "0")"
	}

}
