class AddIndexOnPrototypeToSpreeOptionTypePrototype < ActiveRecord::Migration[5.0]
  def change
    duplicates = Spree::OptionTypePrototype.group(:prototype_id, :option_type_id).having('sum(1) > 1').size

    duplicates.each do |f|
      prototype_id, option_type_id = f.first
      count = f.last - 1 # we want to leave one record
      otp = Spree::OptionTypePrototype.where(prototype_id: prototype_id, option_type_id: option_type_id).last(count)
      otp.map(&:destroy)
    end

    if index_exists? :spree_option_type_prototypes, [:prototype_id, :option_type_id]
      remove_index :spree_option_type_prototypes, [:prototype_id, :option_type_id]
      add_index :spree_option_type_prototypes, [:prototype_id, :option_type_id], unique: true, name: 'spree_option_type_prototypes_prototype_id_option_type_id'
    end

    add_index :spree_option_type_prototypes, :prototype_id
  end
end
