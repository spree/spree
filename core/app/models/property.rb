class Property < ActiveRecord::Base
  has_and_belongs_to_many :prototypes

  has_many :product_properties, :dependent => :destroy
  has_many :products, :through => :product_properties

  validates :name, :presentation, :presence => true

  scope :sorted, order(:name)

  def self.find_all_by_prototype(prototype)
    id = prototype
    if prototype.class == Prototype
      id = prototype.id
    end
    joins('left join properties_prototypes on property_id = properties.id').where('prototype_id = ?', id)
  end
end
