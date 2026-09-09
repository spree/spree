class CreateSpreePackageTypes < ActiveRecord::Migration[8.1]
  def change
    # The store's packaging vocabulary: the boxes it ships in, and the
    # cartons, pallets and containers wholesale orders leave on.
    create_table :spree_package_types do |t|
      t.references :store, null: false
      t.string :name, null: false
      t.string :kind, null: false
      t.decimal :length, precision: 8, scale: 2
      t.decimal :width, precision: 8, scale: 2
      t.decimal :height, precision: 8, scale: 2
      t.string :dimensions_unit
      # The empty package's own weight (box plus filler), added to content
      # weight on every quote — distinct from max_weight, what it can hold.
      t.decimal :weight, precision: 10, scale: 2
      t.decimal :max_weight, precision: 10, scale: 2
      t.string :weight_unit
      t.boolean :default, null: false, default: false
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end
      t.timestamps
    end

    add_index :spree_package_types, [:store_id, :name], unique: true,
              name: 'index_spree_package_types_on_store_and_name'

    # One default package type per store — the box the store usually ships
    # in. MySQL ignores +where:+, so the model validation carries it there.
    unless ActiveRecord::Base.connection.adapter_name.match?(/mysql/i)
      add_index :spree_package_types, :store_id, unique: true,
                where: '"default" = TRUE',
                name: 'index_spree_package_types_default_per_store'
    end
  end
end
