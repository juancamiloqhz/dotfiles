# Music launcher

`music` is a data-driven front end for CLIamp. It separates three ways of
choosing what to hear:

- **Focus** chooses by work state: deep, flow, think, energy, chill, or mellow.
- **Sources** chooses a publisher or station network, including Productivity FM.
- **Browse** opens a full CLIamp provider such as YouTube Music or radio.

Run `music` to navigate interactively, or address any catalog path directly:

```bash
music
music focus deep
music source productivity-fm
music source soma-fm drone-zone
music browse library
```

## Architecture

- `../bin/music` contains generic menu navigation and action execution.
- `catalog.tsv` defines the complete hierarchy and every playable target.
- `cliamp/radios.toml` exposes the direct radio stations inside CLIamp.
- `cliamp/config.example.toml` supplies safe defaults on a new machine.

The catalog has five tab-separated fields:

```text
path    label    description    action    target
```

Supported actions:

- `menu` creates a branch. Its target must be `-`.
- `alias` maps an intent such as `focus/deep` to one canonical playable source.
- `url` plays a stream, feed, video, or playlist URL with CLIamp.
- `provider` opens a CLIamp provider such as `ytmusic` or `radio`.
- `youtube-channel` loads recent channel uploads with `yt-dlp`, presents a
  selection menu, and plays the chosen video with CLIamp.

Every nested entry needs a parent `menu` entry. Validate changes with:

```bash
music doctor
bash scripts/test-music.sh
```

## Adding a source

Most additions require one catalog row. For a publisher with several stations,
create a menu branch and add its children:

```text
source/example-fm    Example FM    Human-curated radio    menu    -
source/example-fm/ambient    Ambient    Quiet ambient station    url    https://example.com/ambient.mp3
```

If that station becomes the default for a focus mode, point the mode at the
canonical source rather than repeating its URL:

```text
focus/deep    Deep    Minimal ambient for demanding work    alias    source/example-fm/ambient
```

Use a channel's stable `/videos` URL for a `youtube-channel` action. Avoid
pinning a single upload unless that exact mix is intentionally permanent.

## New-machine setup

`install.sh` installs CLIamp and `yt-dlp` through Homebrew, links `music` into
`~/.local/bin`, and links the radio catalog into CLIamp's configuration.

Configure YouTube Music once after installation:

```bash
cliamp setup
```

## Private state

These files remain local and must never be committed:

```text
~/.config/cliamp/config.toml
~/.config/cliamp/ytmusic_credentials.json
~/.config/cliamp/ytmusic_classification.json
```

The real configuration contains the OAuth client secret, and the credentials
file contains authorization tokens. CLIamp may also save mutable UI choices in
the local configuration when it exits.
