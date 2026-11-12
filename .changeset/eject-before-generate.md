---
"@spree/cli": minor
"create-spree-app": patch
---

`spree generate` now ejects a project still on the prebuilt image before running, after asking, because the prebuilt image never loads files written to `server/`. With no terminal to ask in, it stops and prints the exact `spree generate --yes …` command to run once the developer agrees. The deprecated `spree bundle add <gem>` now installs the gem through `spree add`, and `spree bundle add|remove|install|update|lock` refuses on a project that is not ejected instead of changing nothing. New projects' agent instructions describe this in one line instead of a section.

`spree eject` now switches `docker-compose.yml` over only after the development database is prepared and the stack is up, so an eject that stops part-way no longer leaves a project that looks ejected but still runs the prebuilt image. The next command that needs an ejected project ejects it again.

`spree add dashboard --template` and its environment variables now accept only a local directory or an `https://`, `ssh://`, `git://` or `user@host:path` git URL, so a value like `ext::…` can no longer reach git transports that run commands.
