class AddScopesToSpreeApiKeys < ActiveRecord::Migration[7.2]
  def change
    # `if_not_exists:` isn't honored on column-adder methods (`t.jsonb`/`t.json`)
    # inside a `change_table` block — Rails raises rather than silently
    # ignoring it. `add_column` supports the option directly.
    if connection.adapter_name.match?(/postg/i)
      add_column :spree_api_keys, :scopes, :jsonb, if_not_exists: true
    else
      add_column :spree_api_keys, :scopes, :json, if_not_exists: true
    end
  end
end
