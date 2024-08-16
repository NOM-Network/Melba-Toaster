# Toaster

This is the presentation part of NOM Network's AI VTuber **[Melba Toast](https://www.twitch.tv/melbathetoast/)**.

Written using [Godot](https://godotengine.org/) and GDScript, this program allows Melba Toast's model to speak, show animations, have expressions and such, driven by the backend. Includes the Control Panel, which can be used to drive the model, OBS Studio and moderate incoming speech. Also includes Greenscreen mode for streaming via Discord or other services to 3rd party.

Communication with the backend follows [this API schema](API_SCHEMA.md).

**Control panel interface**
![Interface](readme_assets/interface.png?1)

## Going live

This [Wiki page](https://github.com/NOM-Network/Melba-Toaster/wiki/Going-live) contains instructions on how to go live using the [Release version of the Toaster](https://github.com/NOM-Network/Melba-Toaster/releases).

### Song support

Melba can sing! Song support is outlined in [Wiki](https://github.com/NOM-Network/Melba-Toaster/wiki/Song-support).

## Development

1. Install the latest minor version of Godot 4.3:

    - standalone: <https://godotengine.org/download/windows/>
    - via winget:

    ```powershell
    winget install GodotEngine.GodotEngine
    ```

2. Clone this repo via Git:

    ```bash
    git clone https://github.com/NOM-Network/Melba-Toaster.git
    ```

    Alternatively, you can Download ZIP package using the green "Code" button and unzip it.

3. In the `dist/config` folder, duplicate `prod.cfg.example` file, rename it to `debug.cfg` and fill it out with the connection details for both OBS and backend websockets (make sure they are available).

4. Open the project in Godot.

5. Hit F5 in Godot editor. Live2D and Control Panel scenes should start automatically.

> The project can run without OBS and/or the backend, but nothing will actually happen. This can be useful for testing the songs. If you need to test yapping capabilities of the model, use the [mock backend server](backend/README.md) in the `backend` folder.
>
> When pushing changes to the repository, ignore or revert any `Param` changes in `scenes\live2d\live_2d_melba.tscn` - they are control parameters for the model and are changed in the runtime. If you use GitHub Desktop, you can ignore these lines from commit by clicking on the line block.

### Note for Mac/Linux users

This project is built for use on Windows and uses Windows libraries for Cubism extension. If you need to use Toaster on Mac or Linux, you have to [build the extension first](https://github.com/MizunagiKB/gd_cubism/blob/main/docs/BUILD.en.adoc), then put the files in `addons/gd_cubism/bin` folder.

### Build machine perparations

Moved to [Wiki](https://github.com/NOM-Network/Melba-Toaster/wiki/Build-machine-perparations)

## License

Melba Toast © 2023-present NOM Network and contributors.

Project codebase is licensed under a [AGPL 3.0 (and later) license](LICENSE.md).

Art assets are licensed under a [CC BY-SA 4.0 license](LICENSE-ASSETS.md).

## Acknowledgements

This project uses the following 3rd party libraries and assets:

- [Godot Engine](https://godotengine.org), licensed under the MIT license.

- [Cubism for GDScript](https://github.com/MizunagiKB/gd_cubism) by MizunagiKB, licensed under the MIT license.

- [Live2D Cubism SDK](https://github.com/Live2D/CubismNativeFramework) by Live2D, licensed under the [Cubism SDK Release License](https://www.live2d.com/en/sdk/license).

- [Shantell Sans font](https://shantellsans.com), licensed under the SIL Open Font License, Version 1.1.

- [Spout GD](https://github.com/you-win/spout-gd), licensed under the MPL 2.0 license.

- [Spout2](https://github.com/leadedge/Spout2), licensed under the BSD 2-Clause license.

License files are available in [licenses/](licenses/) folder of this repository.
