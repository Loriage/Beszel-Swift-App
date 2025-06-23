# Beszel Companion

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg?logo=swift)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2017%2B-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/github/license/Loriage/Beszel-Swift-App?color=%239944ee)](./LICENSE)
[![Made with SwiftUI](https://img.shields.io/badge/Made%20with-SwiftUI-blue.svg?logo=swift)](https://developer.apple.com/xcode/swiftui/)

An unofficial, native iOS client for the [Beszel](https://github.com/henrygd/beszel) server monitoring platform.

This application allows you to view your server and container statistics directly from your iPhone by connecting to your Beszel instance's API.

## Overview

|                                                  Home                                                  |                                                    System                                                    |                                                   Containers                                                   |                                                    Detail View                                                    |
| :----------------------------------------------------------------------------------------------------: | :----------------------------------------------------------------------------------------------------------: | :------------------------------------------------------------------------------------------------------------: | :---------------------------------------------------------------------------------------------------------------: |
| <img src="https://github.com/Loriage/Beszel-Swift-App/blob/main/screenshots/pinned.png" width="200" /> | <img src="https://github.com/Loriage/Beszel-Swift-App/blob/main/screenshots/system_stats.png" width="200" /> | <img src="https://github.com/Loriage/Beszel-Swift-App/blob/main/screenshots/container_list.png" width="200" /> | <img src="https://github.com/Loriage/Beszel-Swift-App/blob/main/screenshots/container_details.png" width="200" /> |

## Features

-   **Secure Connection**: Connects to your Beszel instance via its API. Credentials are securely stored in the iOS Keychain.
-   **Custom Dashboard**: Pin your favorite charts (System CPU, a specific container's memory, etc.) to a home screen for quick access.
-   **System Stats**: Visualize historical data for CPU usage, memory usage, and temperatures of your host systems.
-   **Container Stats**: Browse a list of all your Docker containers and analyze their historical CPU and memory consumption.
-   **Interactive Charts**: Clean and responsive charts built with Swift Charts.
-   **Time Range Filtering**: Display data from the last hour, last 24 hours, last 7 days, and more.
-   **Native Experience**: A smooth and integrated user experience, built entirely with SwiftUI.
-   **Dark Mode Support**: The interface automatically adapts to your device's theme.

## Client Architecture

Unlike Beszel, which consists of a **hub** and an **agent**, **Beszel Swift App** is a single client that communicates directly with your Beszel **hub**'s API. It requires no additional installation on your servers.

## Getting Started

### Prerequisites

1.  A working [Beszel](https://beszel.dev/guide/getting-started) instance that is accessible from the internet.
2.  Xcode 15 or newer.
3.  An iPhone device or simulator running iOS 17 or newer. This project is tested with iOS 26.

### Installation

1.  Clone this repository:
    ```bash
    git clone https://github.com/Loriage/Beszel-Swift-App.git
    ```
2.  Open the `Beszel-companion.xcodeproj` project in Xcode.
3.  Run the application. The onboarding screen will prompt you to enter your Beszel instance URL, email, and password.

## Technologies Used

-   **SwiftUI**: For the entire declarative and reactive user interface.
-   **Swift Charts**: For creating all charts within the application.
-   **Swift Concurrency (`async/await`)**: For modern and performant network calls.
-   **Combine**: For state management of shared objects (`ObservableObject`).
-   **WidgetKit**: (Future) To display information on the Home Screen.

## Roadmap

-   [ ] Home Screen & Lock Screen Widgets.
-   [ ] Push notifications via Beszel's webhooks.
-   [ ] Enhanced chart interactivity (scrubbing).
-   [ ] Localization into other languages.

## Acknowledgements

A huge thank you to [henrygd](https://github.com/henrygd) for creating Beszel, a fantastic, lightweight, and open-source monitoring tool. This mobile client would not exist without his remarkable work.

## License

This project is distributed under the MIT License. See the [LICENSE](./LICENSE) file for more details.
