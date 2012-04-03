module Spree
  class Property < ActiveRecord::Base
    has_and_belongs_to_many :prototypes, :join_table => 'spree_properties_prototypes'

    has_many :product_properties, :dependent => :destroy
    has_many :products, :through => :product_properties

    attr_accessible :name, :presentation

    validates :name, :presentation, :presence => true

    scope :sorted, lambda { order(:name) }

    def self.find_all_by_prototype(prototype)
      id = prototype
      if prototype.class == Prototype
        id = prototype.id
      end
      joins("LEFT JOIN properties_prototypes ON property_id = #{self.table_name}.id").where(:prototype_id => id)
    end
  end
end
