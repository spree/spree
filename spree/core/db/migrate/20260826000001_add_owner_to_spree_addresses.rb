class AddOwnerToSpreeAddresses < ActiveRecord::Migration[8.1]
  def up
    # One relationship with three cardinalities: a customer's address book, a
    # company node's, and a seller's billing address. The user FK becomes the
    # first case of a polymorphic owner rather than a column the other two have
    # to work around — and what an address requires (a person's name, or a
    # company's) follows from who owns it, so the Spree::BusinessAddress
    # subclass that used to carry those rules is gone.
    add_column :spree_addresses, :owner_type, :string
    add_column :spree_addresses, :owner_id, :bigint
    add_index :spree_addresses, [:owner_type, :owner_id], name: 'index_spree_addresses_on_owner'

    Spree::Address.unscoped.where.not(user_id: nil).
      update_all(owner_type: Spree.customer_class.to_s, owner_id: Arel.sql('user_id'))

    remove_column :spree_addresses, :user_id
  end

  def down
    add_column :spree_addresses, :user_id, :bigint
    add_index :spree_addresses, :user_id, name: 'index_spree_addresses_on_user_id'

    Spree::Address.unscoped.where(owner_type: Spree.customer_class.to_s).
      update_all(user_id: Arel.sql('owner_id'))

    remove_index :spree_addresses, name: 'index_spree_addresses_on_owner'
    remove_column :spree_addresses, :owner_type
    remove_column :spree_addresses, :owner_id
  end
end
