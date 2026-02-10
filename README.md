# Beszel Companion

[![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg?logo=swift)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2018%2B-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/github/license/Loriage/Beszel-Swift-App?color=%239944ee)](./LICENSE)
[![Made with SwiftUI](https://img.shields.io/badge/Made%20with-SwiftUI-blue.svg?logo=swift)](https://developer.apple.com/xcode/swiftui/)
[![Crowdin](https://badges.crowdin.net/beszel-swift-app/localized.svg)](https://crowdin.com/project/beszel-swift-app)

**Beszel Companion** is an unofficial, native iOS client for the [Beszel](https://github.com/henrygd/beszel) server monitoring platform.

This application allows you to view your server and container statistics directly from your iPhone by connecting to your Beszel instance's API.

> [!IMPORTANT]  
> **A working Beszel instance accessible from the internet is required to use Beszel Companion.**
>
> By default, only an `admin` user can read all data. For better security, you can create a `readonly` user by modifying API route access in your PocketBase settings.

> [!NOTE]
> You can log in to your instance via the SSO configured on Beszel.
> 
> Please note that you will need to add `beszel-companion://redirect` to the redirect_uris of your SSO providers.
 
## Overview

|                                                 Home                                                 |                                                 System                                                 |                                                 Containers                                                 |                                               Detail View                                               |
| :--------------------------------------------------------------------------------------------------: | :----------------------------------------------------------------------------------------------------: | :--------------------------------------------------------------------------------------------------------: | :-----------------------------------------------------------------------------------------------------: |
| <img src="https://github.com/Loriage/Beszel-Swift-App/blob/main/screenshots/home.jpg" width="200" /> | <img src="https://github.com/Loriage/Beszel-Swift-App/blob/main/screenshots/system.jpg" width="200" /> | <img src="https://github.com/Loriage/Beszel-Swift-App/blob/main/screenshots/containers.jpg" width="200" /> | <img src="https://github.com/Loriage/Beszel-Swift-App/blob/main/screenshots/details.jpg" width="200" /> |

## Key Features

-   [x] **Secure Connection**: Connects to your Beszel instance via its API. Credentials are securely stored in the iOS Keychain.
-   [x] **Custom Dashboard**: Pin your favorite charts (System CPU, a specific container's memory, etc.) to a home screen for quick access.
-   [x] **Powerful Search & Sorting**: Instantly find any pinned chart on your dashboard with a robust search bar and flexible sorting options.
-   [x] **System Stats**: Visualize historical data for CPU usage, memory usage, and temperatures of your host systems.
-   [x] **Container Stats**: Browse a list of all your Docker containers and analyze their historical CPU and memory consumption.
-   [x] **Interactive Charts**: Clean and responsive charts built with Swift Charts.
-   [x] **Time Range Filtering**: Display data from the last hour, last 24 hours, last 7 days, and more.
-   [x] **Native Experience**: A smooth and integrated user experience, built entirely with SwiftUI.
-   [x] **Dark Mode Support**: The interface automatically adapts to your device's theme.
-   [x] **Widgets**: Display key information directly on your Home Screen.
-   [x] **Multiple hub management**: Easily manage and monitor multiple Beszel hubs and their associated systems
-   [x] **SSO support**
-   [x] **Enhanced chart interactivity**

## Roadmap

-   [ ] Lock Screen Widgets.
-   [ ] MacOS support
-   [ ] Push notifications.
-   [ ] Localization into other languages (Open to contributions)

## Technologies Used

-   **SwiftUI**: For the entire declarative and reactive user interface.
-   **Swift Charts**: For creating all charts within the application.
-   **Swift Concurrency (`async/await`)**: For modern and performant network calls.
-   **WidgetKit**: To display information on the Home Screen.

## Installation

<a href="https://apps.apple.com/us/app/beszel/id6747600765"><img src="https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/en-us?size=250x83&amp;releaseDate=1712361600" alt="Download on the App Store" style="border-radius: 13px; width: 200px; height: 66px;"></a>

### Alternative Methods

-   Sideload the `.ipa` from [releases](https://github.com/Loriage/Beszel-Swift-App/releases/latest)

## Known Issues

### Widgets on Sideloaded App

The Home Screen widgets will not function if you install the app by sideloading the .ipa file. This is a known limitation due to iOS security policies, as sideloading prevents the widget from securely sharing data and credentials with the main app through the required App Group.

For the best experience, including widget support, please download the official version from the App Store.

### SSO / OAuth Authentication

Some SSO providers, like Google, have security policies that do not support custom URL schemes for redirects. This means that authentication through these providers will not work unless the Beszel API is updated to support a `https` redirect endpoint for mobile clients.

## Acknowledgements

A huge thank you to [henrygd](https://github.com/henrygd) for creating Beszel, a fantastic, lightweight, and open-source monitoring tool. This mobile client would not exist without his remarkable work.

## License

This project is distributed under the MIT License. See the [LICENSE](./LICENSE) file for more details.
