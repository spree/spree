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

    def self.default
      country_id = Spree::Config[:default_country_id]
      country_id.present? ? find(country_id) : find_by!(iso: 'US')
    end

    def <=>(other)
      name <=> other.name
    end

    def to_s
      name
    end
  end
end
