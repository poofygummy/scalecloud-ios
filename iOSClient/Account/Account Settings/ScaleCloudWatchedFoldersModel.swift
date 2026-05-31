// SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
// SPDX-License-Identifier: GPL-3.0-or-later

/// =============================================================================
/// WHAT THIS FILE DOES (for people learning the code)
/// =============================================================================
///
/// This file contains the "brain" (ViewModel) for the screen where a ScaleCloud
/// user can manage the list of folders they want the app to automatically watch
/// for new downloaded files.
///
/// Why does this exist?
/// - On iOS, apps cannot freely access folders belonging to other apps.
/// - The only safe way for the user to give us access to a folder is by picking
///   it themselves using the system document picker.
/// - When they pick a folder, iOS gives us a "security-scoped bookmark" (a special
///   token that lets us access that folder later).
/// - We need to save those tokens, load them later, turn them back into real
///   folder URLs, and let the user add/remove them.
///
/// This model handles all of that logic so the SwiftUI view can stay relatively simple.
///
/// It is only shown for accounts that pass the isToCsaCloud check (ScaleCloud accounts).
///
/// =============================================================================

import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// This is a SwiftUI ViewModel (@ObservableObject) that manages the list of
/// "Watched Download Folders" for a single ScaleCloud account.
///
/// Its job is to:
/// - Load the list of folders the user previously chose
/// - Let the user add new folders (via the Files app picker)
/// - Let the user remove folders
/// - Handle all the complicated iOS security rules around accessing folders the user picked
///
/// This model is only used by ScaleCloudWatchedFoldersView.swift.
@MainActor
class ScaleCloudWatchedFoldersModel: ObservableObject {

    // The list of folders we are currently watching.
    // @Published means the SwiftUI view will automatically refresh when this array changes.
    @Published var watchedFolders: [URL] = []

    @Published var isLoading = false

    // The account this list belongs to (e.g. "user@cloud.example.com")
    private let account: String

    // We use NCPreferences to load and save the bookmarks persistently.
    private let preferences = NCPreferences()

    init(account: String) {
        self.account = account
        // As soon as the model is created, load whatever folders the user has already saved.
        loadBookmarks()
    }

    /// Loads the saved bookmarks from storage and turns them into real folder URLs we can use.
    func loadBookmarks() {
        // Ask NCPreferences for the raw bookmark Data we previously saved for this account.
        let bookmarkDatas = preferences.getScaleCloudWatchedDownloadBookmarks(account: account)
        var resolved: [URL] = []

        for data in bookmarkDatas {
            var isStale = false

            // Turn the saved bookmark Data back into a real URL.
            // The .withSecurityScope option tells iOS we want to keep the permission
            // to access this folder in the future.
            if let url = try? URL(resolvingBookmarkData: data,
                                  options: .withSecurityScope,
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &isStale),
               !isStale {
                resolved.append(url)
            }
        }

        // Update the published property → the UI will refresh.
        watchedFolders = resolved
    }

    /// Called when the user picks a new folder using the document picker.
    /// We must do the "security scoped bookmark dance":
    /// 1. Start accessing the folder right now
    /// 2. Ask iOS to create a bookmark token we can save
    /// 3. Save that token using NCPreferences
    /// 4. Refresh the list so the UI updates
    func addFolder(url: URL) {
        // Ask iOS for permission to access this folder right now.
        // If this returns false, we are not allowed to read it.
        guard url.startAccessingSecurityScopedResource() else { return }

        // This guarantees that no matter what happens (success or error),
        // we will release the access when this function ends.
        defer {
            url.stopAccessingSecurityScopedResource()
        }

        do {
            // Ask iOS to create a bookmark token for this folder.
            // .withSecurityScope means the bookmark will carry permission to access the folder later.
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope,
                                                    includingResourceValuesForKeys: nil,
                                                    relativeTo: nil)

            // Load the current list of bookmarks we already have for this account
            var current = preferences.getScaleCloudWatchedDownloadBookmarks(account: account)

            // Add the new one
            current.append(bookmarkData)

            // Save the updated list back to persistent storage
            preferences.setScaleCloudWatchedDownloadBookmarks(account: account, bookmarks: current)

            // Refresh the list so the UI shows the newly added folder
            loadBookmarks()
        } catch {
            print("Failed to create bookmark: \(error)")
        }
    }

    /// Removes one or more folders from the watched list.
    /// This just removes the bookmark data from storage — it does not delete anything on disk.
    func removeFolder(at offsets: IndexSet) {
        var current = preferences.getScaleCloudWatchedDownloadBookmarks(account: account)

        for index in offsets.reversed() {
            if index < watchedFolders.count {
                watchedFolders.remove(at: index)
                current.remove(at: index)
            }
        }

        preferences.setScaleCloudWatchedDownloadBookmarks(account: account, bookmarks: current)
    }

    /// Opens the system folder picker so the user can choose a new folder to watch.
    /// This is a UIKit component, so we need some glue code (the Coordinator).
    func presentDocumentPicker(on controller: UIViewController) {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true

        // The document picker needs a delegate to tell us which folder the user picked.
        let delegate = FolderPickerDelegate { [weak self] url in
            self?.addFolder(url: url)
        }

        // Keep the delegate alive as long as the picker exists
        objc_setAssociatedObject(picker, &AssociatedKeys.delegate, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        picker.delegate = delegate
        controller.present(picker, animated: true)
    }
}

// Helper struct so we can attach the delegate to the picker using associated objects.
private struct AssociatedKeys {
    static var delegate = "FolderPickerDelegate"
}

/// This is the delegate that receives the folder the user selected in the document picker.
/// When the user picks a folder, we call the closure that was passed in (which calls model.addFolder).
private class FolderPickerDelegate: NSObject, UIDocumentPickerDelegate {
    let onPick: (URL) -> Void

    init(onPick: @escaping (URL) -> Void) {
        self.onPick = onPick
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        onPick(url)
    }
}