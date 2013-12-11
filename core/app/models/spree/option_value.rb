module Spree
  class OptionValue < ActiveRecord::Base
    belongs_to :option_type, :class_name => 'Spree::OptionType', :touch => true
    acts_as_list scope: :option_type
    has_and_belongs_to_many :variants, join_table: 'spree_option_values_variants', class_name: "Spree::Variant"

    validates :name, :presentation, presence: true

    attr_accessible :name, :presentation
  end
end
