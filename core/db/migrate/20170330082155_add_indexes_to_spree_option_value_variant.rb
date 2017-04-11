class AddIndexesToSpreeOptionValueVariant < ActiveRecord::Migration[5.0]
  def change
    duplicates = Spree::OptionValueVariant.group(:variant_id, :option_value_id).having('sum(1) > 1').size

    duplicates.each do |f|
      variant_id, option_value_id = f.first
      count = f.last - 1 # we want to leave one record
      ov = Spree::OptionValueVariant.where(variant_id: variant_id, option_value_id: option_value_id).last(count)
      ov.map(&:destroy)
    end

    if index_exists? :spree_option_value_variants, [:variant_id, :option_value_id], name: "index_option_values_variants_on_variant_id_and_option_value_id"
      remove_index :spree_option_value_variants, [:variant_id, :option_value_id]
      add_index :spree_option_value_variants, [:variant_id, :option_value_id], unique: true, name: "index_option_values_variants_on_variant_id_and_option_value_id"
    end

    add_index :spree_option_value_variants, :variant_id
  end
end
