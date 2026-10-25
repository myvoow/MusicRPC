# MusicRPC

MacOS 26 Apple Music RPC for Discord.

App de barre de menu qui affiche dans Discord le morceau en cours dans Apple Music : titre, artiste, progression et pochette (iTunes puis Deezer).

## Installation

1. Sur https://discord.com/developers/applications, créez une application. Son nom est ce qui s'affiche après « Écoute ».
2. `./build.sh && open MusicRPC.app`
3. Cliquez sur la note dans la barre de menu et collez l'**Application ID**.

## Tests

Avec Xcode : `swift test`. Avec les Command Line Tools seules :

```sh
D=/Library/Developer/CommandLineTools/Library/Developer
swift test -Xswiftc -F -Xswiftc $D/Frameworks -Xlinker -rpath -Xlinker $D/Frameworks -Xlinker -rpath -Xlinker $D/usr/lib
```

`Vendor/mediaremote-adapter` : copie de [ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) (BSD, commit dans `COMMIT`). C'est ce qui lit le « Now Playing » depuis macOS 15.4.
