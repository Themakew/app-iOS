//
//  WebViewController.swift
//  MacMagazine
//
//  Created by Cassio Rossi on 30/03/2019.
//  Copyright © 2019 MacMagazine. All rights reserved.
//

import SafariServices
import UIKit
import WebKit

protocol WebViewControllerDelegate {
	func previewActionFavorite(_ post: PostData?)
	func previewActionShare(_ post: PostData?)
	func previewActionCancel()
}

class WebViewController: UIViewController {

	// MARK: - Properties -

	@IBOutlet private weak var webView: WKWebView!
	@IBOutlet private weak var spin: UIActivityIndicatorView!
	@IBOutlet private weak var share: UIBarButtonItem!
	@IBOutlet private weak var favorite: UIBarButtonItem!

	var delegate: WebViewControllerDelegate?

	var post: PostData? {
		didSet {
			configureView()
		}
	}

	var postURL: URL? {
		didSet {
			guard let url = postURL else {
				return
			}
			loadWebView(url: url)
		}
	}

	var forceReload: Bool = false

	// MARK: - View lifecycle -

	override func viewDidLoad() {
        super.viewDidLoad()

		// Do any additional setup after loading the view.
		NotificationCenter.default.addObserver(self, selector: #selector(reload(_:)), name: .reloadWeb, object: nil)

		favorite.image = UIImage(named: post?.favorito ?? false ? "fav_on" : "fav_off")
		self.parent?.navigationItem.rightBarButtonItems = [share, favorite]

        webView?.navigationDelegate = self
		webView?.uiDelegate = self

		// Make sure that all cookies are loaded before
		// That's prevent Disqus from being loogoff
		let cookies = API().getDisqusCookies()
		var cookiesLeft = cookies.count
		if cookies.isEmpty {
			reload()
		} else {
			cookies.forEach { cookie in
				webView?.configuration.websiteDataStore.httpCookieStore.setCookie(cookie) {
					cookiesLeft -= 1
					if cookiesLeft <= 0 {
						DispatchQueue.main.async {
							self.reload()
						}
					}
				}
			}
		}
    }

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		NotificationCenter.default.addObserver(self, selector: #selector(onFavoriteUpdated(_:)), name: .favoriteUpdated, object: nil)
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

		NotificationCenter.default.removeObserver(self, name: .favoriteUpdated, object: nil)
        userActivity?.invalidate()
	}

	// MARK: - Local methods -

	func configureView() {
		// Update the user interface for the detail item.
		guard let post = post,
			let link = post.link,
			let url = URL(string: link)
			else {
				return
		}

        if webView?.url != url ||
			forceReload {
			loadWebView(url: url)

            // Handoff
            userActivity?.invalidate()

            let handoff = NSUserActivity(activityType: "com.brit.macmagazine.details")
            handoff.title = post.title
            handoff.webpageURL = URL(string: link)
            userActivity = handoff
        }
	}

	func loadWebView(url: URL) {
        UserDefaults.standard.removeObject(forKey: "offset")

        // Changes the WKWebView user agent in order to hide some CSS/HT elements
        webView?.customUserAgent = "MacMagazine\(Settings().darkModeUserAgent)\(Settings().fontSizeUserAgent)"
        webView?.allowsBackForwardNavigationGestures = false
        webView?.load(URLRequest(url: url))

        self.parent?.navigationItem.rightBarButtonItems = [UIBarButtonItem(customView: spin)]

        forceReload = false
	}

	// MARK: - Actions -

	@IBAction private func favorite(_ sender: Any) {
		guard let post = post,
			let link = post.link
			else {
				return
		}
		Favorite().updatePostStatus(using: link) { isFavoriteOn in
			self.favorite.image = UIImage(named: isFavoriteOn ? "fav_on" : "fav_off")
		}
	}

	@IBAction private func share(_ sender: Any) {
		guard let post = post,
			let link = post.link,
			let url = URL(string: link)
			else {
                guard let url = postURL else {
                    return
                }
                let items: [Any] =  [webView.title ?? "", url]
                Share().present(at: share, using: items)
                return
		}
		let items: [Any] =  [post.title ?? "", url]
		Share().present(at: share, using: items)
	}

	// MARK: - UIPreviewAction -

	override var previewActionItems: [UIPreviewActionItem] {
		let favoritar = UIPreviewAction(title: "Favoritar", style: .default) { [weak self] _, _ in
			self?.delegate?.previewActionFavorite(self?.post)
		}
		let compartilhar = UIPreviewAction(title: "Compartilhar", style: .default) { [weak self] _, _ in
			self?.delegate?.previewActionShare(self?.post)
		}
		let cancelar = UIPreviewAction(title: "Cancelar", style: .destructive) { [weak self] _, _  in
			self?.delegate?.previewActionCancel()
		}

		// Temporary change the colors
		Settings().applyLightTheme()

		return [favoritar, compartilhar, cancelar]
	}

}

// MARK: - Notifications -

extension WebViewController {

	func reload() {
		if post != nil {
			configureView()
		} else if postURL != nil {
			guard let url = postURL else {
				return
			}
			loadWebView(url: url)
			self.navigationItem.rightBarButtonItems = [UIBarButtonItem(customView: spin)]
		}
	}

	@objc func reload(_ notification: Notification) {
		forceReload = true
		reload()
	}

	@objc func onFavoriteUpdated(_ notification: Notification) {
		if Settings().isPad {
			guard let object = notification.object as? Post else {
				return
			}
			if post?.link == object.link {
				post?.favorito = object.favorite
				favorite.image = UIImage(named: post?.favorito ?? false ? "fav_on" : "fav_off")
				self.parent?.navigationItem.rightBarButtonItems = [share, favorite]
			}
		}
	}

}

// MARK: - WebView Delegate -

extension WebViewController: WKNavigationDelegate, WKUIDelegate {

	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
		self.parent?.navigationItem.rightBarButtonItems = [share, favorite]
		self.navigationItem.rightBarButtonItems = nil

        if self.navigationController?.viewControllers.count ?? 0 > 1 {
            self.navigationItem.rightBarButtonItems = [share]
        }

        userActivity?.becomeCurrent()
}

	func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {

		if !(navigationAction.targetFrame?.isMainFrame ?? false) {
			guard let url = navigationAction.request.url else {
				return nil
			}

			if url.isKnownAddress() {
				pushNavigation(url)
			} else {
				openInSafari(url)
			}
		}
		return nil
	}

	func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

		var actionPolicy: WKNavigationActionPolicy = .allow

		guard let url = navigationAction.request.url else {
			decisionHandler(actionPolicy)
			return
		}
		let isMMAddress = url.isMMAddress()

		switch navigationAction.navigationType {
		case .linkActivated:
			if isMMAddress {
				pushNavigation(url)
			} else {
				openInSafari(url)
			}
			actionPolicy = .cancel

		case .other:
			if url.absoluteString == navigationAction.request.mainDocumentURL?.absoluteString {
				if webView.isLoading {
					if webView.url?.absoluteString == "https://disqus.com/next/login-success/" {
						actionPolicy = .cancel
						DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
							self.navigationController?.popViewController(animated: true)
							DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
								NotificationCenter.default.post(name: .reloadWeb, object: nil)
							}
						}
					}
				} else {
					if isMMAddress {
						pushNavigation(url)
					} else {
						openInSafari(url)
					}
					actionPolicy = .cancel
				}
			}

		default:
			break
		}

		decisionHandler(actionPolicy)
	}

}

extension WebViewController {

	func pushNavigation(_ url: URL) {
        // Prevent double pushViewController due decidePolicyFor navigationAction == .other
        if self.navigationController?.viewControllers.count ?? 0 <= 1 {
            let storyboard = UIStoryboard(name: "WebView", bundle: nil)
            guard let controller = storyboard.instantiateViewController(withIdentifier: "PostDetail") as? WebViewController else {
                return
            }
            controller.postURL = url

            controller.modalPresentationStyle = .overFullScreen
            self.navigationController?.pushViewController(controller, animated: true)
        } else {
            loadWebView(url: url)
            self.navigationItem.rightBarButtonItems = [UIBarButtonItem(customView: spin)]
        }
	}

	func openInSafari(_ url: URL) {
		if url.scheme?.lowercased().contains("http") ?? false {
			let safari = SFSafariViewController(url: url)
			if Settings().isDarkMode {
				safari.preferredBarTintColor = UIColor.black
			}
			safari.dismissButtonStyle = .close
			safari.modalPresentationStyle = .overFullScreen

			self.present(safari, animated: true, completion: nil)
		}
	}

}

extension WebViewController {
	func delay(_ delay: Double, closure: @escaping () -> Void) {
		let when = DispatchTime.now() + delay
		DispatchQueue.main.asyncAfter(deadline: when, execute: closure)
	}
}

// MARK: - Extensions -

extension URL {

	enum Address {
		static let disqus = "disqus.com"
		static let macmagazine = "macmagazine.uol.com.br"
		static let blank = "about:blank"
	}

	func isKnownAddress() -> Bool {
		return self.absoluteString.contains(Address.disqus) ||
			self.absoluteString.contains(Address.macmagazine)
	}

	func isMMAddress() -> Bool {
		return self.absoluteString.contains(Address.macmagazine)
	}

	func isDisqusAddress() -> Bool {
		return self.absoluteString.contains(Address.disqus)
	}

	func isBlankAddress() -> Bool {
		return self.absoluteString.contains(Address.blank)
	}

}
