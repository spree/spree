# Spree Assistant

AI chat assistant for the Spree admin dashboard. Optional — install the gem,
connect an AI provider in **Settings → Integrations**, and a chat panel appears
in the dashboard.

The assistant answers questions about store data and performs merchant tasks
through a set of permission-gated tools. It runs on
[RubyLLM](https://rubyllm.com), so it works with Claude (the default), OpenAI or
Gemini; which vendor a store uses is a store setting.

## Two rules it is built around

**It can only do what you can do.** Every tool executes as the signed-in admin,
scoped to the current store, through the same endpoints and workflows the Admin
API uses. The
tools offered to the model are filtered by that admin's permissions — someone
without permission to edit products is never offered a tool that edits products.

**Nothing changes without your say-so.** A tool that would change the store
stops and asks. You see what it wants to do and approve or reject it. This is
also what keeps the store safe from text it reads: a product description or
customer note can ask for a price change, but it cannot get one.

## Installation

```ruby
gem 'spree_assistant'
```

```bash
bundle install
bin/rails spree:install:migrations
bin/rails db:migrate
```

Then connect a provider in the dashboard under Settings → Integrations.

## Tools

The assistant uses Spree's shared agent tools (`Spree.admin_agent_tools`), the
same ones the MCP server offers. A tool an extension registers there reaches
both, with no assistant code involved:

```ruby
# server/config/initializers/spree.rb
Spree.admin_agent_tools << MyApp::AgentTools::RestockVariant
```

Any tool declared `mutating!` waits behind an approval card in the dashboard.
Its `summary` is the sentence the merchant decides on, so write one that names
the record and the change.

See `docs/plans/6.0-dashboard-assistant.md` for the full design.
