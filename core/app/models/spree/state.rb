module Spree
  class State < ActiveRecord::Base
    belongs_to :country, class_name: 'Spree::Country'

    validates :country, :name, presence: true

    attr_accessible :name, :abbr

    def self.find_all_by_name_or_abbr(name_or_abbr)
      where("#{quoted_table_name}.name = ? OR #{quoted_table_name}.abbr = ?", name_or_abbr, name_or_abbr)
    end

    # table of { country.id => [ state.id , state.name ] }, arrays sorted by name
    # blank is added elsewhere, if needed
    def self.states_group_by_country_id
      state_info = Hash.new { |h, k| h[k] = [] }
      self.order("#{quoted_table_name}.name ASC").each { |state|
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
