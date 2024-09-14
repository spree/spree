class AddDisplayOnToSpreeProperties < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_properties, :display_on, :string, default: 'both'

    Spree::Property.reset_column_information
    Spree::Property.update_all(display_on: 'both')
  end
end
