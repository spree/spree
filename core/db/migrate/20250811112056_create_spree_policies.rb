class CreateSpreePolicies < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_policies do |t|
      t.belongs_to :store, null: false
      t.string :slug, null: false
      t.string :name, null: false
      t.boolean :show_in_checkout_footer, null: false, default: true, index: true
      t.integer :position, null: false, default: 0, index: true

      t.timestamps
    end

    add_index :spree_policies, [:store_id, :slug], unique: true
    add_index :spree_policies, [:store_id, :show_in_checkout_footer]

    create_table :spree_policy_translations do |t|
      t.string :locale, null: false
      t.string :name
      t.references :spree_policy, null: false

      t.timestamps
    end

    add_index :spree_policy_translations, [:spree_policy_id, :locale], unique: true
  end
end
