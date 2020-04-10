//
//  FetchedResultsControllerDataSource.swift
//  MacMagazine
//
//  Created by Cassio Rossi on 04/03/2019.
//  Copyright © 2019 MacMagazine. All rights reserved.
//

import CoreData
import UIKit

protocol FetchedResultsControllerDelegate: AnyObject {
	func willDisplayCell(indexPath: IndexPath)
	func didSelectRowAt(indexPath: IndexPath)
	func configure(cell: PostCell, atIndexPath: IndexPath)
	func scrollViewDidScroll(_ scrollView: UIScrollView)
	func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool)
}

extension FetchedResultsControllerDelegate {
	func willDisplayCell(indexPath: IndexPath) {}
	func didSelectRowAt(indexPath: IndexPath) {}
}

class FetchedResultsControllerDataSource: NSObject, UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate {

	// MARK: - Properties -

	weak var delegate: FetchedResultsControllerDelegate?

	fileprivate var tableView: UITableView?
    fileprivate let managedObjectContext = CoreDataStack.shared.viewContext
    fileprivate var groupedBy: String?

    public let fetchRequest: NSFetchRequest<Post> = Post.fetchRequest()

	fileprivate lazy var fetchedResultsController: NSFetchedResultsController = { () -> NSFetchedResultsController<Post> in
		// Initialize Fetched Results Controller
		let controller = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)

		return controller
	}()

	// MARK: - Initialization methods -

    init(withTable tableView: UITableView, group: String?, featuredCellNib: String) {
        super.init()
        self.groupedBy = group
        setup(tableView: tableView)

		self.tableView?.register(UINib(nibName: "HeaderCell", bundle: nil), forHeaderFooterViewReuseIdentifier: "headerCell")
        self.tableView?.register(UINib(nibName: featuredCellNib, bundle: nil), forCellReuseIdentifier: "featuredCell")
    }

    func setup(tableView: UITableView) {
        self.tableView = tableView
        self.tableView?.dataSource = self
        self.tableView?.delegate = self
        self.tableView?.register(UINib(nibName: "NormalCell", bundle: nil), forCellReuseIdentifier: "normalCell")
    }

	// MARK: - Scroll detection -

	func scrollViewDidScroll(_ scrollView: UIScrollView) {
		delegate?.scrollViewDidScroll(scrollView)
	}

	func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
		delegate?.scrollViewDidEndDragging(scrollView, willDecelerate: decelerate)
	}

	// MARK: - TableView methods -

	func numberOfSections(in tableView: UITableView) -> Int {
		let numSections = sections()

		let favorite = fetchRequest.predicate?.predicateFormat.contains("favorite") ?? false
		let category = fetchRequest.predicate?.predicateFormat.contains("categorias") ?? false

		if (numSections == 0 || rows(in: 0) == 0) &&
			(favorite || category) {

			let notFound = UILabel(frame: CGRect(x: 0, y: 0, width: tableView.bounds.size.width, height: tableView.bounds.size.height))
			notFound.text = favorite ? "Você ainda não favoritou nenhum \(self.groupedBy == nil ? "podcast" : "post")" : "Nenhum resultado encontrado"
			notFound.textColor = Settings().darkModeColor
			notFound.textAlignment = .center
			tableView.backgroundView = notFound
			tableView.separatorStyle = .none

		} else {
			tableView.backgroundView = nil
			tableView.separatorStyle = hasMoreThanOneLine() ? .singleLine : .none
		}

		return numSections
	}

	func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		guard let sections = fetchedResultsController.sections,
			let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "headerCell") as? HeaderCell
			else {
				return nil
		}
		let currentSection = sections[section]
		header.setHeader(currentSection.name.isEmpty ? nil : currentSection.name.toHeaderDate())
		return header
	}

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return rows(in: section)
	}

	func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {

		let favoritar = UIContextualAction(style: .normal, title: nil) {
			_, _, boolValue in

			let object = self.fetchedResultsController.object(at: indexPath)
			Favorite().updatePostStatus(using: object.link ?? "") { isFavoriteOn in
				object.favorite = isFavoriteOn
				NotificationCenter.default.post(name: .favoriteUpdated, object: object)
				boolValue(true)
			}
		}
		let object = self.fetchedResultsController.object(at: indexPath)
		favoritar.image = UIImage(named: "fav_cell\(object.favorite ? "" : "_off")")
		favoritar.backgroundColor = UIColor(hex: "0097d4", alpha: 1)
		favoritar.accessibilityLabel = "Favoritar"

		let swipeActions = UISwipeActionsConfiguration(actions: [favoritar])
		swipeActions.performsFirstActionWithFullSwipe = true
		return swipeActions
	}

	func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {

		let compatilhar = UIContextualAction(style: .normal, title: nil) {
			_, _, boolValue in

			let post = self.fetchedResultsController.object(at: indexPath)
			guard let link = post.link,
				let url = URL(string: link)
				else {
					boolValue(true)
					return
			}

			let cell = self.tableView?.cellForRow(at: indexPath)
			let items: [Any] = [post.title ?? "", url]
			Share().present(at: cell, using: items)

			boolValue(true)
		}
		compatilhar.backgroundColor = UIColor(hex: "0097d4", alpha: 1)
		compatilhar.image = UIImage(named: "share")
		compatilhar.accessibilityLabel = "Compartilhar"

		let swipeActions = UISwipeActionsConfiguration(actions: [compatilhar])
		swipeActions.performsFirstActionWithFullSwipe = true
		return swipeActions
	}

	func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
		delegate?.willDisplayCell(indexPath: indexPath)
	}

	internal func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		var identifier = "normalCell"
		let object = fetchedResultsController.object(at: indexPath)
		if object.categorias?.contains("Destaques") ?? false {
			identifier = "featuredCell"
		}

		guard let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath) as? PostCell else {
			fatalError("Unexpected Index Path")
		}
		delegate?.configure(cell: cell, atIndexPath: indexPath)
		return cell
	}

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		delegate?.didSelectRowAt(indexPath: indexPath)
	}

	// MARK: - FetchController Delegate methods -

	func reloadData() {
		// Execute the fetch to display the data
		do {
            fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: groupedBy, cacheName: nil)
            fetchedResultsController.delegate = self

            try fetchedResultsController.performFetch()
		} catch {
			print("An error occurred")
		}
	}

	func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		tableView?.beginUpdates()
	}

	func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {

		switch type {
		case .insert:
			tableView?.insertSections(IndexSet(integer: sectionIndex), with: .fade)
		case .delete:
			tableView?.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
		default:
			return
		}
	}

	func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {

		switch type {
		case .update:
			if let indexPath = indexPath {
				if let cell = tableView?.cellForRow(at: indexPath) as? PostCell {
					delegate?.configure(cell: cell, atIndexPath: indexPath)
				}
			}
		case .insert:
			if let indexPath = newIndexPath {
				tableView?.insertRows(at: [indexPath], with: .fade)
			}
		case .delete:
			if let indexPath = indexPath {
				tableView?.deleteRows(at: [indexPath], with: .fade)
			}
		case .move:
			if let indexPath = indexPath {
				tableView?.deleteRows(at: [indexPath], with: .fade)
			}
			if let newIndexPath = newIndexPath {
				tableView?.insertRows(at: [newIndexPath], with: .fade)
			}
		@unknown default:
			break
		}
	}

	func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		tableView?.endUpdates()
	}

	// MARK: -

	func hasData() -> Bool {
		return !(fetchedResultsController.fetchedObjects?.isEmpty ?? true)
	}

	func hasMoreThanOneLine() -> Bool {
		return (fetchedResultsController.fetchedObjects?.count ?? 0 > 1)
	}

	func sections() -> Int {
		guard let sections = self.fetchedResultsController.sections else {
			return 0
		}
		return sections.count
	}

	func rows(in section: Int) -> Int {
		guard let sections = self.fetchedResultsController.sections else {
			return 0
		}
		let sectionInfo = sections[section]
		return sectionInfo.numberOfObjects
	}

	func object(at indexPath: IndexPath) -> Post? {
		return fetchedResultsController.object(at: indexPath)
	}

	func object(with link: String) -> Post? {
		guard let posts = fetchedResultsController.fetchedObjects else {
			return nil
		}
		let filteredPosts = posts.filter { $0.link == link }
		return filteredPosts.isEmpty ? nil : filteredPosts[0]
	}

	func links() -> [PostData] {
		guard let posts = fetchedResultsController.fetchedObjects else {
			return []
		}
		var response = [PostData]()
		for post in posts {
			response.append(PostData(title: post.title, link: post.link, thumbnail: post.artworkURL, favorito: post.favorite))
		}
		return response
	}

	func indexPath(for object: Post) -> IndexPath {
		return fetchedResultsController.indexPath(forObject: object) ?? IndexPath(row: 0, section: 0)
	}

}
