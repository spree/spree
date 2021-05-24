class AddFilterParamToSpreeProductProperties < ActiveRecord::Migration[6.0]
  def change
    unless column_exists?(:spree_product_properties, :filter_param)
      add_column :spree_product_properties, :filter_param, :string
      add_index :spree_product_properties, :filter_param

      # generate filter params
      Spree::ProductProperty.reset_column_information
      Spree::ProductProperty.find_each do |property|
        property.save
      end
    end
  end
end
