class RenameOptionPresentationToLabel < ActiveRecord::Migration[8.1]
  # docs/plans/5.4-store-api-naming-standardization.md. The API has exposed
  # `label` since 5.4 through a locale-aware delegation, but the Ransack
  # whitelist and the validation error keys both carry the column name. The
  # Mobility translation tables move in the same change — the translated value
  # lives there, so leaving them behind would split the field in two.
  def change
    rename_column :spree_option_types, :presentation, :label
    rename_column :spree_option_values, :presentation, :label
    rename_column :spree_option_type_translations, :presentation, :label
    rename_column :spree_option_value_translations, :presentation, :label
  end
end
