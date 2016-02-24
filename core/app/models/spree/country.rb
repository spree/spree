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

    validates :name, :iso_name, presence: true, uniqueness: { case_sensitive: false, allow_blank: true }
    validate :can_have_states?, if: :states_required_changed?

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

    private

    def ensure_not_default
      if id.eql?(Spree::Config[:default_country_id])
        errors.add(:base, Spree.t(:default_country_cannot_be_deleted))
        false
      end
    end

    def can_have_states?
      if !states_required? && states.present?
        errors.add(:states_required, Spree.t(:states_required_invalid))
      end
    end
  end
end
