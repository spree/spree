module Spree
  class Country < Spree::Base
    has_many :states, dependent: :destroy
    has_many :addresses, dependent: :nullify

    has_many :zone_members,
             -> { where(zoneable_type: 'Spree::Country') },
             class_name: 'Spree::ZoneMember',
             dependent: :destroy,
             foreign_key: :zoneable_id

    has_many :zones, through: :zone_members, class_name: 'Spree::Zone'

    validates :name, :iso_name, presence: true

    before_save :clear_cache

    def self.default
      Rails.cache.fetch("#{Rails.application.class.parent_name.underscore}_default_country") do
        country_id = Spree::Config[:default_country_id]
        country_id.present? ? find(country_id) : find_by!(iso: 'US')
      end
    end

    def <=>(other)
      name <=> other.name
    end

    def to_s
      name
    end

    private
    def clear_cache
      Rails.cache.delete("#{Rails.application.class.parent_name.underscore}_default_country")
    end
  end
end
