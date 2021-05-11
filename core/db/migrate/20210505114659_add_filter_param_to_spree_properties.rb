class AddFilterParamToSpreeProperties < ActiveRecord::Migration[6.0]
  def change
    unless column_exists?(:spree_properties, :filter_param)
      add_column :spree_properties, :filter_param, :string
      add_index :spree_properties, :filter_param

      Spree::Property.reset_column_information
      Spree::Property.all.each(&:save)
    end
  end
end
