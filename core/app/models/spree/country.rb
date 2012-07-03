module Spree
  class Country < ActiveRecord::Base
    has_many :states, :order => "name ASC"

    has_one :zone_member, :as => :zoneable
    has_one :zone, :through => :zone_member

    validates :name, :iso_name, :presence => true

    def <=>(other)
      name <=> other.name
    end

    def to_s
      name
    end
  end
end
