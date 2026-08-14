class AddCustomsFieldsToSpreeVariants < ActiveRecord::Migration[8.1]
  def change
    add_column :spree_variants, :hs_code, :string
    add_column :spree_variants, :country_of_origin, :string
    add_column :spree_variants, :customs_description, :string
  end
end
