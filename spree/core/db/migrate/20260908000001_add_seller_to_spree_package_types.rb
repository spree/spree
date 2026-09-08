class AddSellerToSpreePackageTypes < ActiveRecord::Migration[8.1]
  def change
    # Whose packaging this is: a seller's own boxes and cartons, or (nil) the
    # marketplace's — the shared vocabulary every seller may pack into.
    add_reference :spree_package_types, :seller, null: true

    remove_index :spree_package_types, name: 'index_spree_package_types_on_store_and_name'

    # Two indexes where there was one, because a nullable column inside a
    # unique index constrains nothing for the rows where it is null: the
    # marketplace's rows all share a NULL seller_id, and NULLs compare
    # distinct. MySQL has no partial indexes, so there the seller rows are
    # covered (they carry no NULL) and the marketplace's fall back to the
    # model validation — the arrangement the default flag already has.
    if supports_partial_index?
      add_index :spree_package_types, [:store_id, :name], unique: true,
                where: 'seller_id IS NULL',
                name: 'index_spree_package_types_marketplace_name'
      add_index :spree_package_types, [:store_id, :seller_id, :name], unique: true,
                where: 'seller_id IS NOT NULL',
                name: 'index_spree_package_types_seller_name'

      remove_index :spree_package_types, name: 'index_spree_package_types_default_per_store'
      add_index :spree_package_types, :store_id, unique: true,
                where: '"default" = TRUE AND seller_id IS NULL',
                name: 'index_spree_package_types_marketplace_default'
      add_index :spree_package_types, [:store_id, :seller_id], unique: true,
                where: '"default" = TRUE AND seller_id IS NOT NULL',
                name: 'index_spree_package_types_seller_default'
    else
      add_index :spree_package_types, [:store_id, :seller_id, :name], unique: true,
                name: 'index_spree_package_types_seller_name'
    end
  end

  private

  def supports_partial_index?
    !ActiveRecord::Base.connection.adapter_name.match?(/mysql/i)
  end
end
