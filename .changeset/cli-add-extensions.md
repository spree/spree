---
"@spree/cli": minor
"create-spree-app": patch
---

`spree add <extension>` installs an official extension in one step: Stripe, PayPal, Adyen, Avalara AvaTax, Klaviyo, EasyPost, Meilisearch, the MCP server and OpenTelemetry. It ejects a project still on the prebuilt image (after asking), adds the gem at the right version, runs the extension's installer and migrations, installs its dashboard plugin when it has one, and restarts a running server. A failed install puts the Gemfile back as it was. Extensions outside the list install with `spree add --gem <name> --npm <package>`, after a confirmation. New projects' agent instructions point coding agents at `spree add`.
