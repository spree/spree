class AddStoreToSpreeOptionTypes < ActiveRecord::Migration[8.1]
  def up
    add_reference :spree_option_types, :store, null: true, index: true

    # Existing option types were installation-wide, so they belong to the
    # store that has been using them. Left nullable: a fresh install has no
    # store yet, and the association enforces presence from the model side.
    default_store = Spree::Store.where(default: true).first || Spree::Store.first
    Spree::OptionType.update_all(store_id: default_store.id) if default_store

    # Names are unique within a store now, so two stores may each define `size`.
    remove_index :spree_option_types, :name, unique: true, if_exists: true
    add_index :spree_option_types, %i[store_id name], unique: true
  end

  def down
    remove_index :spree_option_types, %i[store_id name]

    # Two stores may each hold a `size` by now, which the global index would
    # refuse. Rolling back means going back to installation-wide option
    # types, so the duplicates are suffixed rather than dropped: no row is
    # lost, and the operator can see what to reconcile. Written in SQL
    # because a migration must not depend on model scopes or callbacks.
    execute(<<~SQL.squish)
      UPDATE spree_option_types
      SET name = #{concat_sql}
      WHERE id NOT IN (
        SELECT MIN(id) FROM spree_option_types GROUP BY name
      )
    SQL

    add_index :spree_option_types, :name, unique: true
    remove_reference :spree_option_types, :store
  end

  private

  # MySQL has no `||` string operator under its default SQL mode.
  def concat_sql
    if connection.adapter_name.downcase.include?('mysql')
      "CONCAT(name, '-', id)"
    else
      "name || '-' || id"
    end
  end
end
