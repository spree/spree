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
    validate :kind_cannot_leave_the_products_packed_in_it, on: :update
    before_save :demote_other_defaults, if: -> { default? && will_save_change_to_default? }
    validate :default_cannot_be_given_up, on: :update
    # prepend so this runs before the association callbacks Rails registers,
    # and is skipped when the store itself is going away.
    before_destroy :ensure_not_default, prepend: true

    scope :default, -> { where(default: true) }

    scope :cartons, -> { where(kind: 'carton') }

    # The one kind anything branches on: a variant may only be packed into a
    # carton. The rest of the vocabulary is the merchant's to name and read.
    #
    # @return [Boolean]
    def carton?
      kind == 'carton'
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

    # Geometry expressed in the unit the given store works in, so a carton
    # a merchant measured in centimetres is still usable by a store that
    # quotes in inches. Nil unless all three sides are recorded.
    #
    # @param unit [String] one of {Spree::Variant::DIMENSION_UNITS}
    # @return [Hash{Symbol => Float}, nil]
    def dimensions_in(unit)
      sides = { length: length, width: width, height: height }
      return if sides.values.any? { |side| side.to_f.zero? }

      sides.transform_values { |side| Spree::Measurement.convert_length(side, from: dimensions_unit, to: unit).to_f }
    end

    # The empty package's own weight in the given unit — the tare added to
    # every quote.
    #
    # @param unit [String] one of {Spree::Variant::WEIGHT_UNITS}
    # @return [BigDecimal]
    def weight_in(unit)
      Spree::Measurement.convert_weight(weight, from: weight_unit, to: unit) || 0
    end

    private

    # Deleting the store's box would leave every quote with no tare and no
    # dimensions, which under-prices bulky shipments silently. Name another
    # default first — unless the store itself is being destroyed, where
    # refusing would abort that too and strand the row.
    def ensure_not_default
      return unless default?
      return if destroyed_by_association.present?

      errors.add(:base, Spree.t('errors.messages.cannot_delete_default_package_type'))
      throw(:abort)
    end

    # A variant may only be packed into a carton, and that is checked when the
    # variant is saved — so letting a carton become a pallet later would leave
    # every product already packed in it pointing at a row it could no longer
    # choose, its geometry still feeding their freight rollups. Repack them
    # first.
    def kind_cannot_leave_the_products_packed_in_it
      return unless kind_changed? && kind_was == 'carton' && kind != 'carton'
      return unless variants.exists?

      errors.add(:kind, :cannot_stop_being_a_carton)
    end

    # Clearing the flag on the only default leaves the store with no box at
    # all, which is the same silent loss as deleting it. Promote another row
    # instead; that demotes this one in the same save.
    def default_cannot_be_given_up
      return unless default_changed? && default_was && !default?
      return if self.class.where(store_id: store_id, default: true).where.not(id: id).exists?

      errors.add(:default, :cannot_be_given_up)
    end

    def demote_other_defaults
      self.class.where(store_id: store_id, default: true).where.not(id: id).update_all(default: false)
    end
  end
end
