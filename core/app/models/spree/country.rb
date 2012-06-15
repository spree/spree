module Spree
  class Country < ActiveRecord::Base
    has_many :states, :order => "name ASC", :class_name => Spree::State

    has_one :zone_member, :as => :zoneable, :class_name => Spree::ZoneMember
    has_one :zone, :through => :zone_member, :class_name => Spree::Zone

    validates :name, :iso_name, :presence => true

    def <=>(other)
      name <=> other.name
    end

    def to_s
      name
    end
  end
end
