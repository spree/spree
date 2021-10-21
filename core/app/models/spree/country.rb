module Spree
  class Country < Spree::Base
    # we need to have this callback before any dependent: :destroy associations
    # https://github.com/rails/rails/issues/3458
    # before_destroy :ensure_not_default

    has_many :addresses, dependent: :restrict_with_error
    has_many :states,
             -> { order name: :asc },
             inverse_of: :country,
             dependent: :destroy
    has_many :zone_members,
             -> { where(zoneable_type: 'Spree::Country') },
             class_name: 'Spree::ZoneMember',
             dependent: :destroy,
             foreign_key: :zoneable_id
    has_many :zones, through: :zone_members, class_name: 'Spree::Zone'

    validates :name, :iso_name, :iso, :iso3, presence: true, uniqueness: { case_sensitive: false, scope: spree_base_uniqueness_scope }

    def self.default(store = nil)
      ActiveSupport::Deprecation.warn(<<-DEPRECATION, caller)
        `Country#default` is deprecated and will be removed in Spree 5.0.
        Please use `current_store.default_country` instead
      DEPRECATION
      store ||= Spree::Store.default
      country_id = store.default_country_id
      default = find_by(id: country_id) if country_id.present?
      default || find_by(iso: 'US') || first
    end

    def self.by_iso(iso)
      where(['LOWER(iso) = ?', iso.downcase]).or(where(['LOWER(iso3) = ?', iso.downcase])).take
    end

    def default?(store = nil)
      store ||= Spree::Store.default
      self == store.default_country
    end

    def <=>(other)
      name <=> other.name
    end

    def to_s
      name
    end

    private

    def ensure_not_default
      ActiveSupport::Deprecation.warn('Country#ensure_not_default is deprecated and will be removed in Spree v5')

      if id.eql?(Spree::Config[:default_country_id])
        errors.add(:base, Spree.t(:default_country_cannot_be_deleted))
        throw(:abort)
      end
    end
  end
end
