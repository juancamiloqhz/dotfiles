# CLIamp focus music

The repository tracks the public, reproducible parts of the setup:

- `../bin/focus` provides the `focus` launcher and interactive mode menu.
- `radios.toml` contains the custom focus stations.
- `config.example.toml` provides safe defaults for a new machine.

`install.sh` symlinks the launcher and radio list into place. It copies the
example configuration only when no CLIamp configuration exists, so it never
overwrites local credentials or preferences.

## Usage

```bash
focus          # interactive menu
focus deep     # minimal-beat ambient
focus flow     # downtempo electronic
focus think    # spacious planning/writing music
focus energy   # faster execution music
focus program  # long-form Music for Programming mixes
focus chill    # instrumental chillsynth
focus mellow   # softer eclectic music
focus library  # YouTube Music playlists
```

## New-machine setup

After running the repository installer, configure YouTube Music once:

```bash
cliamp setup
```

Use a Google Desktop OAuth client with the YouTube Data API v3 and
`youtube.readonly` scope. Browser cookies can be configured for private or
age-gated playback.

## Private state

These files must remain local and must never be committed:

```text
~/.config/cliamp/config.toml
~/.config/cliamp/ytmusic_credentials.json
~/.config/cliamp/ytmusic_classification.json
```

The real configuration contains the OAuth client secret, and the credentials
file contains authorization tokens. CLIamp may also persist UI choices such as
the theme and EQ preset into the local configuration when it exits.
