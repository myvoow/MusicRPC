# MusicRPC

MacOS 26 Apple Music RPC for Discord.

[English](#english) · [Français](#français)

## English

Menu bar app that shows the song playing in Apple Music on Discord: title, artist, progress bar and cover art (from iTunes, then Deezer).

### Install

1. Download `MusicRPC-x.y.zip` from [Releases](https://github.com/myvoow/MusicRPC/releases), unzip it and move `MusicRPC.app` to Applications.
2. The app isn't notarized by Apple, so macOS blocks it on first launch. Run once:
   `xattr -dr com.apple.quarantine /Applications/MusicRPC.app`
3. On https://discord.com/developers/applications, create an application. Its name is what Discord shows after "Listening to".
4. Click the note in the menu bar and paste the **Application ID**.

To build from source instead: `./build.sh && open MusicRPC.app`

### Tests

With Xcode: `swift test`. With the Command Line Tools only:

```sh
D=/Library/Developer/CommandLineTools/Library/Developer
swift test -Xswiftc -F -Xswiftc $D/Frameworks -Xlinker -rpath -Xlinker $D/Frameworks -Xlinker -rpath -Xlinker $D/usr/lib
```

`Vendor/mediaremote-adapter` is a copy of [ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) (BSD, commit in `COMMIT`). It reads "Now Playing" on macOS 15.4 and later.

## Français

App de barre de menu qui affiche dans Discord le morceau en cours dans Apple Music : titre, artiste, progression et pochette (iTunes puis Deezer).

### Installation

1. Téléchargez `MusicRPC-x.y.zip` depuis les [Releases](https://github.com/myvoow/MusicRPC/releases), dézippez-le et placez `MusicRPC.app` dans Applications.
2. L'app n'est pas notarisée par Apple : au premier lancement, macOS la bloque. Lancez une fois :
   `xattr -dr com.apple.quarantine /Applications/MusicRPC.app`
3. Sur https://discord.com/developers/applications, créez une application. Son nom est ce qui s'affiche après « Écoute ».
4. Cliquez sur la note dans la barre de menu et collez l'**Application ID**.

Pour compiler depuis les sources : `./build.sh && open MusicRPC.app`

### Tests

Avec Xcode : `swift test`. Avec les Command Line Tools seules :

```sh
D=/Library/Developer/CommandLineTools/Library/Developer
swift test -Xswiftc -F -Xswiftc $D/Frameworks -Xlinker -rpath -Xlinker $D/Frameworks -Xlinker -rpath -Xlinker $D/usr/lib
```

`Vendor/mediaremote-adapter` : copie de [ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) (BSD, commit dans `COMMIT`). C'est ce qui lit le « Now Playing » depuis macOS 15.4.
