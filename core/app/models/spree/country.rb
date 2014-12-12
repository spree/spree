module Spree
  class Country < Spree::Base
    has_many :states, -> { order('name ASC') }, dependent: :destroy
    has_many :addresses, dependent: :nullify

    has_many :zone_members,
      -> { where(zoneable_type: 'Spree::Country') },
      class_name: 'Spree::ZoneMember',
      foreign_key: :zoneable_id

    has_many :zones, through: :zone_members, class_name: 'Spree::Zone'

    validates :name, :iso_name, presence: true

    def self.states_required_by_country_id
      states_required = Hash.new(true)
      all.each { |country| states_required[country.id.to_s]= country.states_required }
      states_required
    end

    def self.default
      if Spree::Config[:default_country_id].present?
        Spree::Country.find(Spree::Config[:default_country_id])
      else
        Spree::Country.find_by!(iso: 'US')
      end
    end

    def <=>(other)
      name <=> other.name
    end

    def to_s
      name
    end
  end
end
