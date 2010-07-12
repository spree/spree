class State < ActiveRecord::Base
  belongs_to  :country
  scope :order_by_name, order(:name)

  has_one     :zone_member, :as => :zoneable
  has_one     :zone,        :through => :zone_member

  validates :country, :name, :presence => true

  def <=>(other)
    name <=> other.name
  end

  def to_s
    name
  end
end
