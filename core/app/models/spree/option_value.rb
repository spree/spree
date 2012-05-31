module Spree
  class OptionValue < ActiveRecord::Base
<<<<<<< HEAD
    belongs_to :option_type, :class_name => Spree::OptionType
    acts_as_list :scope => :option_type
    has_and_belongs_to_many :variants, :join_table => :spree_option_values_variants, :class_name => Spree::Variant
=======
    belongs_to :option_type, :class_name => "Spree::OptionType"
    acts_as_list :scope => :option_type
    has_and_belongs_to_many :variants, :join_table => 'spree_option_values_variants', :class_name => "Spree::Variant"
>>>>>>> Specify :class_name argument for all belongs_to (and some has_many) associations in core and promo

    attr_accessible :name, :presentation
  end
end
