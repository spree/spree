class AddKindToSpreeOptionTypes < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_option_types, :kind, :string, null: false, default: 'dropdown'
    add_index :spree_option_types, :kind

    # Backfill: option types named 'color'/'colour' get kind 'color_swatch'
    reversible do |dir|
      dir.up do
        execute "UPDATE spree_option_types SET kind = 'color_swatch' WHERE name IN ('color', 'colour')"
      end
    end
  end
end
