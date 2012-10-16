module Spree
  class OptionValue < ActiveRecord::Base
    belongs_to :option_type
    acts_as_list :scope => :option_type
    has_and_belongs_to_many :variants, :join_table => 'spree_option_values_variants', :class_name => "Spree::Variant"

    attr_accessible :name, :presentation

    def option_type_name
      option_type.name
    end
  end
end
