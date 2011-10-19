class Spree::Prototype < ActiveRecord::Base
  has_and_belongs_to_many :properties, :class_name => 'Spree::Property',
                                       :join_table => 'spree_properties_prototypes'
  has_and_belongs_to_many :option_types, :class_name => 'Spree::OptionType',
                                         :join_table => 'spree_option_types_prototypes'
  validates :name, :presence => true
end
