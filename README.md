# Beszel Companion

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg?logo=swift)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2017%2B-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/github/license/Loriage/Beszel-Swift-App?color=%239944ee)](./LICENSE)
[![Made with SwiftUI](https://img.shields.io/badge/Made%20with-SwiftUI-blue.svg?logo=swift)](https://developer.apple.com/xcode/swiftui/)

An unofficial, native iOS client for the [Beszel](https://beszel.dev) monitoring platform.

> [!IMPORTANT]
> A [Beszel](https://beszel.dev) instance is required to use Beszel Companion.

## Overview

|                                                 Home                                                 |                                                 System                                                 |                                                 Containers                                                 |                                               Detail View                                               |
| :--------------------------------------------------------------------------------------------------: | :----------------------------------------------------------------------------------------------------: | :--------------------------------------------------------------------------------------------------------: | :-----------------------------------------------------------------------------------------------------: |
| <img src="https://github.com/Loriage/Beszel-Swift-App/blob/main/screenshots/home.jpg" width="200" /> | <img src="https://github.com/Loriage/Beszel-Swift-App/blob/main/screenshots/system.jpg" width="200" /> | <img src="https://github.com/Loriage/Beszel-Swift-App/blob/main/screenshots/containers.jpg" width="200" /> | <img src="https://github.com/Loriage/Beszel-Swift-App/blob/main/screenshots/details.jpg" width="200" /> |

## Features

-   [x] **Custom Dashboard** for quick access to your favorite charts.
-   [x] **System Stats** (CPU, memory, temperatures).
-   [x] **Container Stats** (CPU, memory).
-   [x] **Time Range Filtering** (last hour, 24h, 7 days, etc.).
-   [x] **Secure Connection** (credentials stored in the iOS Keychain).
-   [x] **Native SwiftUI Experience** and Dark Mode support.
-   [x] **Home Screen Widgets**.
-   [x] **Multiple Beszel instances support.**
-   [ ] Lock Screen Widgets.
-   [ ] Push Notifications.
-   [ ] Enhanced chart interactivity.
-   [ ] More language support.

## Installation

<a href="https://apps.apple.com/us/app/beszel/id6747600765"><img src="https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/en-us?size=250x83&amp;releaseDate=1712361600" alt="Download on the App Store" target="_blank" style="border-radius: 13px; width: 200px; height: 66px;"></a>

#### Alternative Methods
- Sideload .ipa from [releases](https://github.com/Loriage/Beszel-Swift-App/releases/latest)
- Build it yourself

## Technologies Used

-   **SwiftUI**: For the declarative and reactive user interface.
-   **Swift Charts**: For creating all charts within the application.
-   **Swift Concurrency (`async/await`)**: For modern and performant network calls.
-   **Combine**: For state management of shared objects.
-   **WidgetKit**: To display information on the Home Screen.

## Acknowledgements

A huge thank you to [henrygd](https://github.com/henrygd) for creating Beszel, a fantastic, lightweight, and open-source monitoring tool. This mobile client would not exist without his remarkable work.

## License

This project is distributed under the MIT License. See the [LICENSE](./LICENSE) file for more details.
