# This migration comes from spree (originally 20210915064329)
class AddMetadataToSpreeMultipleTables < ActiveRecord::Migration[5.2]
  def change
    %i[
      spree_assets
      spree_option_types
      spree_option_values
      spree_properties
      spree_promotions
      spree_payment_methods
      spree_shipping_methods
      spree_prototypes
      spree_refunds
      spree_customer_returns
      spree_users
      spree_addresses
      spree_credit_cards
      spree_store_credits
    ].each do |table_name|
      change_table table_name do |t|
        if t.respond_to? :jsonb
          add_column table_name, :public_metadata, :jsonb
          add_column table_name, :private_metadata, :jsonb
        else
          add_column table_name, :public_metadata, :json
          add_column table_name, :private_metadata, :json
        end
      end
    end
  end
end
