module Spree
  class Country < Spree.base_class
    has_prefix_id :ctry  # Spree-specific: country

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
  end
end
