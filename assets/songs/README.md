# Song support

Melba can sing! This document outlines how the song support works.

> Current Melba covers are not here for copyright reasons.

## Specification

Each song lives in its own folder, the name of the folder is its ID. Song consists of 3 files:

- `song.mp3` - fully mixed song (or just instrumental)
- `voice.mp3` - only Melba's voice (for the mouth movement)
- `subtitles.txt` - subtitles and actions for the song

`song` and `voice` files must be identical in duration.

> You have to open the project in Godot at least once in order to import the song assets.

## Config file

`songs.cfg` contains the metadata for each song presented in the folder.

```ini
[0] ; unique song position in the menu
id="i_cant_fix_you" ; unique song ID, the same as the folder name
artist="The Living Tombstone" ; song artist
name="I Can't Fix You" ; song name
wait_time=13.83 ; time for the song name fading in on the screen
mute_voice=1 ; mute the voice track (if you have `song.mp3` fully mixed)
reverb=0 ; enabled reverb on the voice track
subtitles=1 ; is subtitles available
```

## Subtitles

`subtitles.txt` is a label file exported from Audacity.

### Preparing subtitles

#### Creating the Label track

- Open the song (or voice)
- Hit <kbd>Ctrl</kbd> + <kbd>B</kbd> to create a Label

> Note: Toaster does not support ranged labels. They will be treated as point labels.

#### Exporting the labels

- Hit "Select" on the Label track
- File -> Export Other -> Export Labels

### Commands

Subtitles file supports multiple tags to change the appearance of the model and do actions inside the Toaster. All the commands start with `&` symbol. Lines without this symbol are deemed as the text for subtitles.

#### &CLEAR

Clear the subtitles

#### &START `BPM`

Sets the Dancing movement to the desired `BPM`

#### &STOP

Stops the Dancing movement

#### &PIN `ASSET_ID` `STATE`

Changes the state of pinnable assets, where `STATE` is 0 or 1

#### &POSITION `POSITION_ID`

Changes the model position on screen

#### &TOGGLE `TOGGLE_ID` `STATE`

Changes the state of the toggle, where `STATE` is 0 or 1

#### &ANIM `ANIM_ID`

Sets the animation for the model
