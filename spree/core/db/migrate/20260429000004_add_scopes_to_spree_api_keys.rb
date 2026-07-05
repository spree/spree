class AddScopesToSpreeApiKeys < ActiveRecord::Migration[7.2]
  def change
    change_table :spree_api_keys do |t|
      if t.respond_to?(:jsonb)
        t.jsonb :scopes
      else
        t.json :scopes
      end
    end
  end
end
