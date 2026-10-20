class AddPostSaleTax < ActiveRecord::Migration[8.1]
  def change
    change_table :spree_tax_lines, bulk: true do |t|
      t.references :return_line_item, index: true
      t.references :claim_line_item, index: true
      t.references :exchange_line_item, index: true
      t.references :original_tax_line, index: true
      t.boolean :credit, default: false, null: false
    end

    change_table :spree_return_line_items, bulk: true do |t|
      t.decimal :included_tax_total, precision: 10, scale: 2, default: 0, null: false
      t.decimal :additional_tax_total, precision: 10, scale: 2, default: 0, null: false
    end

    change_table :spree_claim_line_items, bulk: true do |t|
      t.decimal :included_tax_total, precision: 10, scale: 2, default: 0, null: false
      t.decimal :additional_tax_total, precision: 10, scale: 2, default: 0, null: false
    end

    change_table :spree_exchange_line_items, bulk: true do |t|
      t.decimal :original_included_tax_total, precision: 10, scale: 2, default: 0, null: false
      t.decimal :original_additional_tax_total, precision: 10, scale: 2, default: 0, null: false
      t.decimal :new_included_tax_total, precision: 10, scale: 2, default: 0, null: false
      t.decimal :new_additional_tax_total, precision: 10, scale: 2, default: 0, null: false
    end

    add_column :spree_refunds, :tax_amount, :decimal, precision: 10, scale: 2, default: 0, null: false
  end
end
