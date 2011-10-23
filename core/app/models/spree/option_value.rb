class Spree::OptionValue < ActiveRecord::Base
  belongs_to :option_type, :class_name => 'Spree::OptionType'
  acts_as_list :scope => :option_type
  has_and_belongs_to_many :variants, :class_name => 'Spree::Variant', :join_table => 'spree_option_values_variants'
end
