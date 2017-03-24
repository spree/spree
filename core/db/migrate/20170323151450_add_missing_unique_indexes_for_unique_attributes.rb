class AddMissingUniqueIndexesForUniqueAttributes < ActiveRecord::Migration[5.0]
  def change
    tables = {
      spree_countries: [:name, :iso_name],
      spree_option_types: [:name],
      spree_option_values: [:name],
      spree_promotions: [:path],
      spree_refund_reasons: [:name],
      spree_reimbursement_types: [:name],
      spree_return_authorization_reasons: [:name],
      spree_roles: [:name],
      spree_shipping_categories: [:name],
      spree_stores: [:code],
      spree_tax_categories: [:name],
      spree_trackers: [:analytics_id],
      spree_zones: [:name]
    }

    tables.each do |table, columns|
      columns.each do |column|
        unless index_exists?(table, column, unique: true)
          remove_index table, column if index_exists?(table, column)
          add_index table, column, unique: true
        end
      end
    end
  end
end
