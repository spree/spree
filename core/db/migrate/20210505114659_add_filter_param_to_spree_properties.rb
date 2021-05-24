class AddFilterParamToSpreeProperties < ActiveRecord::Migration[6.0]
  def change
    unless column_exists?(:spree_properties, :filter_param)
      add_column :spree_properties, :filter_param, :string
      add_index :spree_properties, :filter_param

      # generate filter params
      Spree::Property.reset_column_information
      Spree::Property.find_each do |property|
        property.save
      end
    end
  end
end
