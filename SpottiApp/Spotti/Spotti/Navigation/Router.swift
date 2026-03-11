import SwiftUI
import Combine

enum NavigationDestination: Hashable {
    case home
    case search
    case library
    case playlistDetail(id: String)
    case albumDetail(id: String)
    case artistDetail(id: String)
    case radioQueue
    case likedSongs
}

class Router: ObservableObject {
    @Published var destination: NavigationDestination = .home
    @Published var navigationStack: [NavigationDestination] = []

    func navigate(to dest: NavigationDestination) {
        navigationStack.append(destination)
        destination = dest
    }

    func goBack() {
        if let previous = navigationStack.popLast() {
            destination = previous
        }
    }

    var canGoBack: Bool {
        !navigationStack.isEmpty
    }
}
