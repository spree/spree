class AddStoreToSpreeOptionTypes < ActiveRecord::Migration[8.1]
  def up
    add_reference :spree_option_types, :store, null: true, index: true

    # Existing option types were installation-wide, so they belong to the
    # store that has been using them. Left nullable: a fresh install has no
    # store yet, and the association enforces presence from the model side.
    # Read without the models: Spree::Store expects its columns (preferences,
    # metadata) in the format later migrations convert them to, so loading a
    # store here crashes on a database upgraded from an earlier release.
    stores = Arel::Table.new(:spree_stores)
    default_store_id = connection.select_value(
      stores.project(stores[:id]).where(stores[:deleted_at].eq(nil)).order(stores[:default].desc, stores[:id].asc).take(1)
    )
    if default_store_id.present?
      option_types = Arel::Table.new(:spree_option_types)
      connection.update(Arel::UpdateManager.new.table(option_types).set([[option_types[:store_id], default_store_id]]))
    end

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
