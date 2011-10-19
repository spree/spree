class Spree::State < ActiveRecord::Base
  belongs_to :country, :class_name => 'Spree::Country'

  has_one :zone_member, :as => :zoneable, :class_name => 'Spree::ZoneMember'
  has_one :zone, :through => :zone_member, :class_name => 'Spree::Zone'

  validates :country, :name, :presence => true

  def <=>(other)
    name <=> other.name
  end

  def to_s
    name
  end
end
