class ChangeSpreeUserIdentitiesInfoToJsonb < ActiveRecord::Migration[7.2]
  def up
    change_table :spree_user_identities do |t|
      t.change :info, :jsonb, using: 'info::jsonb' if t.respond_to?(:jsonb)
    end
  end

  def down
    change_table :spree_user_identities do |t|
      t.change :info, :json, using: 'info::json' if t.respond_to?(:jsonb)
    end
  end
end
