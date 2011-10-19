class Spree::Property < ActiveRecord::Base
  has_and_belongs_to_many :prototypes, :join_table => 'spree_properties_prototypes'

  has_many :product_properties, :dependent => :destroy, :class_name => 'Spree::ProductProperty'
  has_many :products, :through => :product_properties, :class_name => 'Spree::Product'

  validates :name, :presentation, :presence => true

  scope :sorted, lambda { order(:name) }

  def self.find_all_by_prototype(prototype)
    id = prototype
    if prototype.class == Prototype
      id = prototype.id
    end
    joins("LEFT JOIN properties_prototypes ON property_id = #{self.table_name}.id").where('prototype_id = ?', id)
  end
end
