class AddStoreToSpreeOptionTypes < ActiveRecord::Migration[8.1]
  def up
    add_reference :spree_option_types, :store, null: true, index: true

    # Existing option types were installation-wide, so they belong to the
    # store that has been using them. A multi-store install that shared one
    # across stores keeps the row working — nothing reads store_id to resolve
    # a product's options (docs/plans/6.0-cli-configurator.md).
    default_store_id = select_value('SELECT id FROM spree_stores WHERE "default" = TRUE LIMIT 1') ||
                       select_value('SELECT id FROM spree_stores ORDER BY id LIMIT 1')
    execute("UPDATE spree_option_types SET store_id = #{quote(default_store_id)}") if default_store_id

    change_column_null :spree_option_types, :store_id, false if default_store_id

    # Names are unique within a store now, so two stores may each define `size`.
    remove_index :spree_option_types, :name, unique: true, if_exists: true
    add_index :spree_option_types, [:store_id, :name], unique: true
  end

  def down
    remove_index :spree_option_types, [:store_id, :name]
    add_index :spree_option_types, :name, unique: true
    remove_reference :spree_option_types, :store
  end
end
