class ReplacePaymentMethodDisplayOnWithStorefrontVisible < ActiveRecord::Migration[8.1]
  # Payment methods are the last host of the tri-state display_on column
  # (docs/plans/5.5-6.0-display-on-to-boolean.md). Only back_end ever meant
  # "hide from the storefront"; both and the legacy front_end-only value
  # collapse to true.
  def up
    add_column :spree_payment_methods, :storefront_visible, :boolean, default: true, null: false
    execute(<<~SQL.squish)
      UPDATE spree_payment_methods
      SET storefront_visible = #{connection.quoted_false}
      WHERE display_on = 'back_end'
    SQL
    remove_column :spree_payment_methods, :display_on
  end

  def down
    add_column :spree_payment_methods, :display_on, :string, default: 'both'
    execute(<<~SQL.squish)
      UPDATE spree_payment_methods
      SET display_on = 'back_end'
      WHERE storefront_visible = #{connection.quoted_false}
    SQL
    remove_column :spree_payment_methods, :storefront_visible
  end
end
