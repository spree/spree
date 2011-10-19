class Spree::OptionType < ActiveRecord::Base
  has_many :option_values, :order => :position, :dependent => :destroy, :class_name => 'Spree::OptionValue'
  has_many :product_option_types, :dependent => :destroy, :class_name => 'Spree::ProductOptionType'
  has_and_belongs_to_many :prototypes, :class_name => 'Spree::Prototype'

  validates :name, :presentation, :presence => true
  default_scope :order => "#{self.table_name}.position"

  accepts_nested_attributes_for :option_values, :reject_if => lambda { |ov| ov[:name].blank? || ov[:presentation].blank? }, :allow_destroy => true
end
