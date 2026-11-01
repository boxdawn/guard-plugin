# Boxdawn guard

**Stops dangerous commands before Claude Code runs them.**

Boxdawn guard judges every Bash and PowerShell command before Claude Code runs it. A command that would wipe a directory outside your project, force-push over shared history, drop a database or destroy cloud resources is **denied** or **held for your approval**. Everything else passes to Claude Code's own permission settings, untouched. The guard never says allow.

This is the directory edition of the plugin. The guard's source, its fixed rules and its tests are in [boxdawn/guard](https://github.com/boxdawn/guard).

## What this plugin runs, fetches and sends

- **At session start** (`scripts/install.sh` on macOS and Linux, `scripts/install.ps1` on Windows): if the guard build for this version is not in the plugin's data folder yet, the script downloads one file for your machine from the [boxdawn/guard v0.1.1 release](https://github.com/boxdawn/guard/releases/tag/v0.1.1) on GitHub, checks its sha256 against the value written in the script, unpacks it into the data folder and removes the download. A file whose sha256 does not match is discarded. Once the build is in place, later sessions make no download. The request to GitHub carries no command, path or key; GitHub sees your IP address.
- **Before each Bash or PowerShell call**: the hook runs the downloaded `bdxguard` with the call's details on its standard input and returns deny, ask or nothing. This runs on your machine and opens no connection.
- **Until the build is in place** (first session start, no network, or a sha256 mismatch), the hook cannot run and Claude Code blocks the Bash or PowerShell call (`onFailure: block`): no guard, no command.
- **With a Boxdawn API key** in the plugin's settings (`/plugin configure`), the guard also fetches signed rules from Boxdawn in the background at session start. That request carries the key only. Without a key, nothing is sent to Boxdawn.

What the guard sends, keeps and deletes: [boxdawn.com/privacy](https://boxdawn.com/privacy).

## What it covers

`rm`, `find -delete`, `dd`, `truncate`, `chmod -R`, `sed -i` and redirects onto files outside the project; `git` force push, `reset --hard`, `clean`, branch delete and history rewrite; database clients (`DROP`, `TRUNCATE`, `DELETE` without `WHERE`); `terraform destroy`, `kubectl delete`, `helm uninstall`, `aws s3 rm/rb` and other cloud deletes; `docker prune`; privilege escalation and code piped into an interpreter. When nobody can answer a prompt (`bypassPermissions`, `dontAsk`), an ask becomes a deny. The full rules: [`command_rules_source.py`](https://github.com/boxdawn/guard/blob/main/boxdawn_guard/command_rules_source.py).

Builds: Windows x64 (and Windows on Arm through emulation), macOS on Apple silicon and Intel, Linux x64 and ARM64.

## License

[FSL-1.1-ALv2](LICENSE.md). Source-available; each version becomes Apache 2.0 two years after its release. Built by [Boxdawn](https://boxdawn.com).
