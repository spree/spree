class AddTypedStockMovements < ActiveRecord::Migration[8.1]
  # Typed stock movements (docs/plans/6.0-typed-stock-movements.md): a `kind`
  # says what happened to stock and concrete foreign keys say why, replacing
  # the polymorphic originator. `allocated_count` carries the units promised
  # to placed orders, so `count_on_hand` can go back to meaning what a picker
  # can count.
  #
  # `kind` stays nullable until the data task has had a release to type the
  # history; the model requires it, so every row 6.0 writes is typed.
  def change
    change_table :spree_stock_movements, bulk: true do |t|
      t.string :kind
      t.string :reason
      t.references :order
      t.references :fulfillment
      t.references :return
      t.references :exchange
      t.references :stock_transfer
    end

    add_index :spree_stock_movements, :kind

    add_column :spree_stock_levels, :allocated_count, :integer, null: false, default: 0
  end
end
