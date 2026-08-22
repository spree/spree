class AddTypeToSpreeAddresses < ActiveRecord::Migration[8.1]
  def up
    add_column :spree_addresses, :type, :string
    add_index :spree_addresses, :type

    # Rows already referenced as business addresses must carry the type, or
    # the subclass-typed associations read them back as nil — STI filters on
    # it. Both referencing tables are born in 6.0, so this touches no
    # released data and needs no batching.
    business_addresses = Class.new(ActiveRecord::Base) { self.table_name = 'spree_addresses' }
    sellers = Class.new(ActiveRecord::Base) { self.table_name = 'spree_sellers' }
    company_locations = Class.new(ActiveRecord::Base) { self.table_name = 'spree_company_locations' }

    ids = sellers.where.not(billing_address_id: nil).pluck(:billing_address_id) +
          company_locations.where.not(billing_address_id: nil).pluck(:billing_address_id) +
          company_locations.where.not(shipping_address_id: nil).pluck(:shipping_address_id)

    business_addresses.where(id: ids.uniq).update_all(type: 'Spree::BusinessAddress')
  end

  def down
    remove_column :spree_addresses, :type
  end
end
