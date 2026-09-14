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
    add_index :spree_option_types, :name, unique: true
    remove_reference :spree_option_types, :store
  end
end
