module Spree
  class OptionType < ActiveRecord::Base
    has_many :option_values, :order => :position, :dependent => :destroy
    has_many :product_option_types, :dependent => :destroy
    has_and_belongs_to_many :prototypes, :join_table => 'spree_option_types_prototypes'

    attr_accessible :name, :presentation, :option_values_attributes

    validates :name, :presentation, :presence => true
    default_scope :order => "#{self.table_name}.position"

    accepts_nested_attributes_for :option_values, :reject_if => lambda { |ov| ov[:name].blank? || ov[:presentation].blank? }, :allow_destroy => true
  end
end
