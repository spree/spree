module Spree
  class Property < ActiveRecord::Base
    has_and_belongs_to_many :prototypes, :join_table => 'spree_properties_prototypes'

    has_many :product_properties, :dependent => :destroy
    has_many :products, :through => :product_properties

    after_destroy :recalculate_product_group_products

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

    private

    # A fix for #774
    # What was happening was that when a property was deleted, any product group
    # that used the property to calculate included properties was not recalculated
    #
    # Recalculates product group products after the property has been deleted
    def recalculate_product_group_products
      ProductScope.where(:name => "with_property", :arguments => [self.name].to_yaml).each do |scope|
        # Triggers ProductGroup#update_memberships callback to recalculate products
        scope.product_group.save!
      end
    end
  end
end
