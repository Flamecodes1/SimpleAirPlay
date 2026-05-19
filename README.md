# Simple AirPlay

Simple AirPlay is a modern, native Windows Presentation Foundation (WPF) wrapper for the open-source AirPlay engine [UxPlay](https://github.com/FDH2/UxPlay).

It provides a seamless, "Apple-like" User Experience (UX) with a dynamic "Pill" interface (similar to Dynamic Island) that runs without admin privileges and is packaged for the Microsoft Store (MSIX).

## Features
- **Zero-Config**: Uses built-in Windows mDNS, no Apple Bonjour required.
- **Dynamic Pill UI**: A beautiful, unobtrusive UI that floats on your screen.
- **60FPS Video Sync**: Smooth video playback synchronized with the UI.
- **Microsoft Store Ready**: Packaged as MSIX, requiring no admin rights.

## Open Source & License

Since this project bundles and acts as a wrapper for **UxPlay** and **GStreamer**, the entire **Simple AirPlay** project is licensed under the **GNU General Public License v3.0 (GPLv3)**.

You are free to study, modify, and redistribute this software under the terms of the GPLv3.

For the full license text, see the [LICENSE.txt](LICENSE.txt) file in this repository or visit the [GNU GPLv3 page](https://www.gnu.org/licenses/gpl-3.0.html).

## Building from Source

1. Clone the repository.
2. Ensure you have the .NET 9.0 SDK installed.
3. Run `dotnet build`.
4. (Optional) Run `dotnet publish -c Release` to create the MSIX package.

## Credits

- **UxPlay**: [https://github.com/FDH2/UxPlay](https://github.com/FDH2/UxPlay)
- **GStreamer**: [https://gstreamer.freedesktop.org/](https://gstreamer.freedesktop.org/)
