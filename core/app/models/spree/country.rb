module Spree
  class Country < ActiveRecord::Base
    has_many :states, :order => "name ASC"

    validates :name, :iso_name, :presence => true

    attr_accessible :name,:iso_name,:states_required

    def <=>(other)
      name <=> other.name
    end

    def to_s
      name
    end
  end
end
