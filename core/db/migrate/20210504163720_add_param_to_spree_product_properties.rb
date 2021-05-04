class AddParamToSpreeProductProperties < ActiveRecord::Migration[6.0]
  def change
    unless column_exists?(:spree_product_properties, :param)
      add_column :spree_product_properties, :param, :string
      add_index :spree_product_properties, :param

      Spree::ProductProperty.reset_column_information
      Spree::ProductProperty.all.each(&:save)
    end
  end
end
