module Spree
  class State < ActiveRecord::Base
    belongs_to :country

    has_one :zone_member, :as => :zoneable
    has_one :zone, :through => :zone_member

    validates :country, :name, :presence => true

    def self.find_all_by_name_or_abbr(name_or_abbr)
      where("name = ? OR abbr = ?", name_or_abbr, name_or_abbr)
    end

    # table of { country.id => [ state.id , state.name ] }, arrays sorted by name
    # blank is added elsewhere, if needed
    def self.states_group_by_country_id
      state_info = Hash.new { |h, k| h[k] = [] }
      Spree::State.order('name ASC').each { |state|
        state_info[state.country_id.to_s].push [state.id, state.name]
      }
      state_info
    end

    def <=>(other)
      name <=> other.name
    end

    def to_s
      name
    end
  end
end
