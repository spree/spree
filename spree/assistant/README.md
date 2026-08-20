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
scoped to the current store, through the same services the Admin API uses. The
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

## Adding your own tools

Tools are plain classes registered in `Spree::Assistant.tools`:

```ruby
class MyApp::Assistant::Tools::RestockVariant < Spree::Assistant::Tool
  tool_name 'restock_variant'
  description 'Add stock for a variant at a location.'
  permission 'write_stock_levels'
  mutating!

  param :variant_id, description: 'Variant id', required: true
  param :quantity, type: :integer, description: 'Units to add', required: true

  def call(variant_id:, quantity:)
    # scope through context.store, write through a workflow
  end

  def summary(arguments)
    "Add #{arguments[:quantity]} units to #{arguments[:variant_id]}"
  end
end

Spree::Assistant.tools << MyApp::Assistant::Tools::RestockVariant
```

Declaring `mutating!` is what puts a tool behind the approval card. Write
`summary` for anything that mutates — it is the sentence the merchant judges the
change by.

See `docs/plans/6.0-dashboard-assistant.md` for the full design.
