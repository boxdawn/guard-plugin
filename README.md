<div align="center">
  <img src="https://avatars.githubusercontent.com/u/317308737?s=160&v=4" width="80" alt="Boxdawn" />
  <h1>Boxdawn guard</h1>
  <p><strong>Stops dangerous commands before Claude Code runs them.</strong></p>
  <p>
    <a href="https://github.com/boxdawn/guard/releases/latest"><img src="https://img.shields.io/github/v/release/boxdawn/guard?label=release" alt="Latest release" /></a>
    <a href="LICENSE.md"><img src="https://img.shields.io/badge/license-FSL--1.1--ALv2-blue" alt="License: FSL-1.1-ALv2" /></a>
    <img src="https://img.shields.io/badge/platforms-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey" alt="Windows, macOS, Linux" />
  </p>
  <p>
    <a href="https://boxdawn.com">Website</a> ·
    <a href="#install">Install</a> ·
    <a href="#what-this-plugin-runs-fetches-and-sends">What it runs and sends</a> ·
    <a href="https://boxdawn.com/privacy">Privacy</a> ·
    <a href="https://github.com/boxdawn/guard">Source</a>
  </p>
</div>

---

Boxdawn guard judges every Bash and PowerShell command before Claude Code runs it. A command that would wipe a directory outside your project, force-push over shared history, drop a database or destroy cloud resources is **denied** or **held for your approval**. Everything else passes to Claude Code's own permission settings, untouched. The guard never says allow.

This is the directory edition of the plugin. The guard's source, its fixed rules and its tests are in [boxdawn/guard](https://github.com/boxdawn/guard).

## Install

From the Claude plugin directory, or in Claude Code from Boxdawn's own marketplace, which ships every build inside the plugin and downloads nothing at session start:

```
/plugin marketplace add boxdawn/guard
/plugin install boxdawn-guard@boxdawn
```

## What this plugin runs, fetches and sends

- **At session start** (`scripts/install.sh` on macOS and Linux, `scripts/install.ps1` on Windows): if the guard build for this version is not in the plugin's data folder yet, the script downloads one file for your machine from the [boxdawn/guard v0.4.11 release](https://github.com/boxdawn/guard/releases/tag/v0.4.11) on GitHub, checks its sha256 against the value written in the script, unpacks it into the data folder and removes the download. A file whose sha256 does not match is discarded. Once the build is in place, later sessions make no download. The request to GitHub carries no command, path or key; GitHub sees your IP address.
- **Before each Bash or PowerShell call**: the hook runs the downloaded `bdxguard` with the call's details on its standard input and returns deny, ask or nothing. This runs on your machine and opens no connection.
- **Before each Read or Grep call**: the same build checks whether the call reads a secret file by name, also on your machine with no connection.
- **Until the build is in place** (first session start, no network, or a sha256 mismatch), the hook cannot run and Claude Code blocks the Bash or PowerShell call (`onFailure: block`): no guard, no command. Read and Grep calls are not blocked when the guard cannot run.
- **With a Boxdawn API key** in the plugin's settings (`/plugin configure`), the guard also fetches signed rules from Boxdawn in the background at session start. That request carries the key only. On a paid plan the same background process then sends the block record (the tool, deny or ask, the rule ids and where the target sits; never a command or a path) and deletes it from your machine, unless `keep_blocks_local` is on. Without a key, nothing is sent to Boxdawn.

What the guard sends, keeps and deletes: [boxdawn.com/privacy](https://boxdawn.com/privacy).

## What it covers

`rm`, `find -delete`, `dd`, `truncate`, `chmod -R`, `sed -i` and redirects onto files outside the project; `git` force push, `reset --hard`, `clean`, branch delete, history rewrite, `checkout -- .` and `restore .`, `stash drop`; database clients (`DROP`, `TRUNCATE`, `DELETE` without `WHERE`) and tools that reset a database (`prisma migrate reset`, `artisan migrate:fresh`, `supabase db reset`, `alembic downgrade base` and the like); `terraform destroy` and `apply -auto-approve`, `kubectl delete`, `helm uninstall`, `aws s3 rm/rb` and other cloud deletes; `gh repo delete` and `gh api` DELETE; `docker prune` and `compose down -v`; `robocopy /MIR` and `lftp mirror --delete`; `adb` clearing an app's data or deleting on a phone and `fastboot` wiping one; privilege escalation and code piped into an interpreter. A command handed to `bash -c` (also `-lc`, `-ec`), `sudo`, `env`, `timeout`, `nohup`, `setsid`, `flock`, `watch`, `script -c`, `tmux new`, `screen`, `wsl` and the like is judged as if typed directly. When nobody can answer a prompt (`bypassPermissions`, `dontAsk`), an ask becomes a deny. The full rules: [`command_rules_source.py`](https://github.com/boxdawn/guard/blob/main/boxdawn_guard/command_rules_source.py).

Reading a secret file by name (`.env` files, SSH private keys, cloud and package-registry credentials and the like) asks; sending one out is denied. This is a check on file names, not a sandbox: what it does not see is listed in the [guard README](https://github.com/boxdawn/guard#secret-files).

Builds: Windows x64 (and Windows on Arm through emulation), macOS on Apple silicon and Intel, Linux x64 and ARM64.

## License

[FSL-1.1-ALv2](LICENSE.md). Source-available; each version becomes Apache 2.0 two years after its release. Built by [Boxdawn](https://boxdawn.com).
