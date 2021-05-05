class RenameParamToFilterParamOnSpreeProductProperties < ActiveRecord::Migration[6.0]
  def change
    rename_column :spree_product_properties, :param, :filter_param
  end
end
