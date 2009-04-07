class Property < ActiveRecord::Base
  has_and_belongs_to_many :prototypes

  has_many :product_properties, :dependent => :destroy, :attributes => true
  has_many :products, :through => :product_properties

  validates_presence_of :name, :presentation
  
  named_scope :sorted, :order => :name

  def self.find_all_by_prototype(prototype)
    id = prototype
    if prototype.class == Prototype
      id = prototype.id
    end

    find(:all, :conditions => [ 'prototype_id = ?', id ],
         :joins => 'left join properties_prototypes on property_id = properties.id')
  end
end
