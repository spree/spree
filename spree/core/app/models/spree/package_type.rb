module Spree
  # A kind of packaging the store uses: the box it ships parcels in, the
  # cartons its products are packed into, the pallets those cartons stack on,
  # the containers a wholesale order fills.
  #
  # Geometry lives here rather than on the things packed into it because
  # merchants reuse a handful of standard sizes across hundreds of products —
  # one edit to a carton row fixes every product packed in that carton. What
  # varies per product (how many units fit, what a packed carton weighs) stays
  # on the variant.
  #
  # See docs/plans/6.0-b2b-wholesale-shipping.md.
  class PackageType < Spree.base_class
    KINDS = %w[box envelope carton pallet container].freeze

    has_prefix_id :pkgtype

    include Spree::SingleStoreResource
    include Spree::Metadata

    belongs_to :store, class_name: 'Spree::Store'

    has_many :variants, class_name: 'Spree::Variant', foreign_key: :carton_package_type_id,
             inverse_of: :carton_package_type, dependent: :restrict_with_error

    validates :name, presence: true, uniqueness: { scope: spree_base_uniqueness_scope + [:store_id] }
    validates :kind, inclusion: { in: KINDS }
    validates :dimensions_unit, inclusion: { in: Spree::Variant::DIMENSION_UNITS }, allow_blank: true
    validates :weight_unit, inclusion: { in: Spree::Variant::WEIGHT_UNITS }, allow_blank: true
    validates :length, :width, :height, :weight, :max_weight,
              numericality: { greater_than_or_equal_to: 0, allow_nil: true }

    # Demote any prior default in the same transaction so the partial unique
    # index ("one default per store") never sees two TRUE rows, and MySQL —
    # which cannot enforce that index — arrives at the same place.
    before_save :demote_other_defaults, if: -> { default? && will_save_change_to_default? }

    scope :default, -> { where(default: true) }

    KINDS.each do |package_kind|
      scope package_kind.pluralize.to_sym, -> { where(kind: package_kind) }

      define_method(:"#{package_kind}?") { kind == package_kind }
    end

    self.whitelisted_ransackable_attributes = %w[name kind default]

    # The unit the geometry is expressed in, falling back to what the store's
    # unit system implies — the same fallback a variant's dimensions take.
    #
    # @return [String]
    def dimensions_unit
      self[:dimensions_unit].presence || Spree::Variant.store_dimensions_unit(store)
    end

    # @return [String]
    def weight_unit
      self[:weight_unit].presence || store&.preferred_weight_unit || Spree::Measurement::DEFAULT_WEIGHT_UNIT
    end

    # The cubic meters this package occupies. Nil until all three dimensions
    # are recorded — a partially measured box has no volume to report.
    #
    # @return [BigDecimal, nil]
    def volume
      Spree::Measurement.cubic_meters(length, width, height, unit: dimensions_unit)
    end

    # Geometry as the carrier rate providers want it, in the recorded unit.
    # Nil unless all three sides are present and positive.
    #
    # @return [Hash{Symbol => Float}, nil]
    def dimensions
      sides = { length: length.to_f, width: width.to_f, height: height.to_f }
      return if sides.values.any?(&:zero?)

      sides
    end

    private

    def demote_other_defaults
      self.class.where(store_id: store_id, default: true).where.not(id: id).update_all(default: false)
    end
  end
end
