class AddDefaultLocaleToSpreeStore < ActiveRecord::Migration[6.0]
  def change
    unless column_exists?(:spree_stores, :default_locale)
      add_column :spree_stores, :default_locale, :string
    end
  end
end
