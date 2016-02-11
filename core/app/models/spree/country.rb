module Spree
  class Country < Spree::Base
    has_many :states, dependent: :destroy
    has_many :addresses, dependent: :restrict_with_error

    has_many :zone_members,
             -> { where(zoneable_type: 'Spree::Country') },
             class_name: 'Spree::ZoneMember',
             dependent: :destroy,
             foreign_key: :zoneable_id

    has_many :zones, through: :zone_members, class_name: 'Spree::Zone'

    before_destroy :ensure_not_default

    validates :name, :iso_name, presence: true

    def self.default
      country_id = Spree::Config[:default_country_id]
      default = find_by(id: country_id) if country_id.present?
      default || find_by(iso: 'US') || first
    end

    def <=>(other)
      name <=> other.name
    end

    def to_s
      name
    end

    private

    def ensure_not_default
      if id.eql?(Spree::Config[:default_country_id])
        errors.add(:base, Spree.t(:default_country_cannot_be_deleted))
        false
      end
    end
  end
end
