<div align="center">
  <img src="assets/rocketlog-icon.png" width="128" alt="RocketLog icon" />
  <h1>RocketLog</h1>
  <p>Read Shadowrocket connection logs from your macOS menu bar.</p>
  <p>macOS 13+ · Swift · MIT</p>
  <p><a href="README.md">中文</a> · English</p>
</div>

---

RocketLog is a native macOS menu bar app that reads local Shadowrocket connection logs. It shows recorded destinations, ports, timestamps, routing results, matching rules, and node text when available.

This is an independent project, not affiliated with or endorsed by Shadowrocket or its developers. It is a log viewer, not a proxy client, and requires existing local Shadowrocket logs.

## Features

- Hover over the menu bar item to open the panel, or click to toggle it.
- Refresh the latest session's most recent 500 records every two seconds.
- Display original `PROXY`, `DIRECT`, `REJECT`, and other recorded results.
- Search by destination, rule, node text, timestamp, or User-Agent.
- Filter by proxy, direct, or reject results.
- Discover new session files automatically or choose a log directory manually.
- Read local logs without packet capture, DNS lookups, or uploads.

The menu bar title reflects the latest record's result. Panel counts describe the loaded records, not active connections.

## Requirements

- macOS 13 or later.
- Shadowrocket with readable local connection logs.
- Apple Command Line Tools, including Swift, to build from source.

Compilation and real-log reading have been verified on Apple Silicon with Swift 5.9. The build script supports `arm64` and `x86_64`; Intel hardware has not been tested.

## Build

Install Command Line Tools if needed:

```sh
xcode-select --install
```

Download or clone this repository, then run these commands from its root:

```sh
chmod +x build.sh
./build.sh
open ./RocketLog.app
```

The generated app can be copied to your Applications folder. Quit an earlier RocketLog instance before replacing it.

Builds use ad-hoc local signing and are not notarized by Apple. Review the source and follow the system's supported opening process if macOS blocks a build. Do not disable Gatekeeper.

Optional build settings:

```sh
ROCKETLOG_ARCH=arm64 ./build.sh
ROCKETLOG_ARCH=x86_64 ./build.sh
ROCKETLOG_APP_PATH="$PWD/dist/RocketLog.app" ./build.sh
```

Each build targets one architecture; these commands do not produce a universal binary.

## Usage

1. Ensure Shadowrocket has generated connection logs.
2. Launch RocketLog. The log panel opens on launch.
3. Hover over or click **RocketLog** in the menu bar.
4. Search and filter the records.
5. If logs are unavailable, choose the directory containing `proxy-*.db` using **选择日志目录**.
6. Use **退出** in the panel to quit.

The current app interface is in Chinese. Launch at login is not configured automatically.

## Data source

Default directory:

```text
~/Library/Group Containers/group.com.liguangming.Shadowrocket/Library/Caches/Logs
```

Supported schema:

```sql
CREATE VIRTUAL TABLE logging USING fts3(
    url text,
    ua text,
    result text,
    type text,
    created DATETIME
);
```

RocketLog opens SQLite with `SQLITE_OPEN_READONLY`, including existing WAL updates. It chooses the newest `proxy-*.db` by filename and reads up to 500 records in descending `rowid` order.

This schema was observed in local files. It is not a public, stable Shadowrocket API and may change.

## Privacy

RocketLog reads connection logs only. It does not read subscription or proxy configuration databases, capture packets, run `lsof` or `nettop`, inspect other applications' connections, resolve DNS, decrypt HTTPS, or contact a server.

Loaded records remain in process memory and are not separately saved. Only a selected directory path is stored in app preferences. RocketLog does not modify or delete Shadowrocket logs and does not require root access.

Repository examples and tests use fictional domains. README badges are served by Shields.io when viewing documentation; the app does not use them.

## Limitations

- Records describe history, not currently active connections or successful requests.
- Traffic absent from Shadowrocket's logs is not shown. Logged `DIRECT` traffic remains visible unless filtered out.
- The supported schema contains no upload/download byte counters, so bandwidth and rates are not displayed.
- A logged domain is not resolved to an IP. IPs appear only when logged as destinations.
- `ua` may contain a protocol hint or User-Agent; it is not a reliable process identifier.
- The list remains unchanged when no new logs arrive. The check time differs from a record's timestamp.
- Only the latest session is shown, with no cross-session history search.
- Missing directories, access restrictions, a busy database, or schema changes produce an error message.

## Validation

```sh
./build.sh
./RocketLog.app/Contents/MacOS/RocketLog --self-test
./RocketLog.app/Contents/MacOS/RocketLog --diagnose
```

`--self-test` creates a temporary FTS3 fixture to check record ordering, result labels, log discovery, and read-only file integrity. It does not write real logs.

`--diagnose` requires real local logs and prints only a source filename, counts, and the most recent timestamp, excluding destination and node content.

## Contributing and license

Read [CONTRIBUTING.md](CONTRIBUTING.md) before filing an issue or pull request. Remove personal browsing data, IPs, node names, and credentials from examples.

Released under the [MIT License](LICENSE). Shadowrocket's name and trademarks belong to their respective owners.
