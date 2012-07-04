module Spree
  class State < ActiveRecord::Base
    belongs_to :country

    has_one :zone_member, :as => :zoneable
    has_one :zone, :through => :zone_member

    validates :country, :name, :presence => true

    attr_accessible :name, :abbr

    def self.find_all_by_name_or_abbr(name_or_abbr)
      where("name = ? OR abbr = ?", name_or_abbr, name_or_abbr)
    end

    def <=>(other)
      name <=> other.name
    end

    def to_s
      name
    end
  end
end
