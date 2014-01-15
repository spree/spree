class MigrateTaxCategoriesToLineItems < ActiveRecord::Migration
  def change
    Spree::LineItem.includes(:variant => { :product => :tax_category }).find_in_batches do |line_items|
      line_items.each do |line_item|
        next if line_item.variant.nil?
        next if line_item.variant.product.nil?
        next if line_item.product.nil?
        line_item.update_column(:tax_category_id, line_item.product.tax_category_id)
      end
    end
  end
end
