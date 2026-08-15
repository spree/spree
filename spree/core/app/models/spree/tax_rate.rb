module Spree
  # Pure tax configuration read by the internal tax provider
  # (Spree::TaxProvider::Internal). Since 6.0 tax rates have no write path of
  # their own — TaxLine rows are written exclusively by the sale's tax provider.
  class TaxRate < Spree.base_class
    has_prefix_id :tax

    # Rates name their country and state directly since 6.0. No code reads
    # zone_id any more, but the column stays in the database through 6.0: it is
    # what `spree:migrate_tax_zones` converts from, and that task runs after
    # db:migrate. The physical drop lands in 6.1.

    acts_as_paranoid

    include Spree::HasCustomFields
    include Spree::Metadata
    include Spree::SingleStoreResource

    with_options inverse_of: :tax_rates do
      belongs_to :tax_category,
                 class_name: 'Spree::TaxCategory'
    end

    has_many :tax_lines, class_name: 'Spree::TaxLine', dependent: :nullify

    with_options presence: true do
      validates :amount, numericality: { allow_nil: true }
      validates :tax_category, :name
    end

    # The jurisdiction this rate applies in, held as codes: a blank country_iso
    # means everywhere, and a country with no state_code means the whole
    # country. Upcased on the way in so a rate entered as "de" still matches an
    # address from Germany.
    has_iso_geography

    # The primitive: rates that reach a jurisdiction, which is a country and
    # optionally one of its states. Rates naming neither are included, since a
    # rate with no country taxes everywhere. Takes the pair rather than an
    # address because tax applies before a customer has given one — the
    # provider falls back to the market's country (see
    # Spree::Purchase::Taxation#tax_country).
    # +normalizes+ above applies to query values too, so a caller passing "de"
    # still matches a rate stored as "DE".
    scope :for_jurisdiction, lambda { |country_iso, state_code = nil|
      where(country_iso: [country_iso.presence, nil].uniq).where(state_code: [state_code.presence, nil].uniq)
    }
    # The same question asked with an address in hand.
    scope :for_address, ->(address) { for_jurisdiction(address&.country_iso, address&.state_code) }
    # Country-wide: unlike for_jurisdiction(country_iso, nil) this leaves the
    # state unconstrained, so it sums a country's state-level rates too. Used
    # where the state is irrelevant — backing VAT out of a gross price.
    scope :for_country, ->(country_iso) { where(country_iso: [country_iso.presence, nil].uniq) }
    scope :for_tax_category,
          ->(category) { where(tax_category_id: category.try(:id)) }
    scope :included_in_price, -> { where(included_in_price: true) }

    self.whitelisted_ransackable_attributes = %w[amount country_iso state_code tax_category_id included_in_price name]

    # Virtual attribute for percentage display in admin forms
    def amount_percentage
      return nil if amount.nil?

      (amount * 100).round(2)
    end

    def amount_percentage=(value)
      self.amount = value.present? ? (value.to_f / 100) : nil
    end

    # The included-in-price rate to back out of a gross price.
    #
    # @param options [Hash] +:country+ (or +:address+) and +:tax_category+
    # @return [BigDecimal] 0 when the jurisdiction or category is unknown
    def self.included_tax_amount_for(options)
      # +:country+ is a documented override point and the VAT path still hands
      # it a Spree::Country, so take the code off whichever arrives.
      country = options[:country]
      country_iso = country.try(:iso) || country.presence || options[:address]&.country_iso
      return 0 unless country_iso && options[:tax_category]

      scope = options[:address] ? for_address(options[:address]) : for_country(country_iso)
      # Per-store tax configuration is the norm since 6.0, so without this the
      # sum would add up every store's rate for the same country.
      store = options[:store] || Spree::Current.store
      scope = scope.for_store(store) if store
      scope.included_in_price.for_tax_category(options[:tax_category]).sum(:amount)
    end

    def included?
      included_in_price
    end

    def additional?
      !included_in_price
    end

    # The customer-facing label snapshotted onto TaxLine rows.
    #
    # @return [String]
    def adjustment_label
      Spree.t included_in_price? ? :including_tax : :excluding_tax,
              scope: 'adjustment_labels.tax_rates',
              name: name.presence || tax_category.name,
              amount: amount_for_label
    end

    private

    def amount_for_label
      return '' unless show_rate_in_label?
      return '' if amount.zero?

      ' ' + ActiveSupport::NumberHelper::NumberToPercentageConverter.convert(
        amount * 100,
        locale: I18n.locale,
        strip_insignificant_zeros: true,
        precision: 2
      )
    end
  end
end
