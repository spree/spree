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

    include Spree::Metafields
    include Spree::Metadata
    include Spree::SingleStoreResource

    with_options inverse_of: :tax_rates do
      belongs_to :tax_category,
                 class_name: 'Spree::TaxCategory'
    end

    # The jurisdiction this rate applies in. Nil country means everywhere, and a
    # country with no state means the whole country.
    belongs_to :country, class_name: 'Spree::Country', optional: true
    belongs_to :state, class_name: 'Spree::State', optional: true

    has_many :tax_lines, class_name: 'Spree::TaxLine', dependent: :nullify

    with_options presence: true do
      validates :amount, numericality: { allow_nil: true }
      validates :tax_category, :name
    end

    before_validation :resolve_state_code
    validate :state_belongs_to_country

    # Rates that reach the given address: its own country and state, plus the
    # broader rates that cover everywhere.
    scope :for_address, lambda { |address|
      where(country_id: [address&.country_id, nil].uniq).
        where(state_id: [address&.state_id, nil].uniq)
    }
    scope :for_country, ->(country) { where(country_id: [country&.id, nil].uniq) }
    # Country and state named directly — the shape the provider matches on,
    # since tax can apply before a customer has given an address at all.
    scope :for_jurisdiction, lambda { |country, state = nil|
      where(country_id: [country&.id, nil].uniq).where(state_id: [state&.id, nil].uniq)
    }
    scope :for_tax_category,
          ->(category) { where(tax_category_id: category.try(:id)) }
    scope :included_in_price, -> { where(included_in_price: true) }

    self.whitelisted_ransackable_attributes = %w[amount country_id state_id tax_category_id included_in_price name]

    # Virtual attribute for percentage display in admin forms
    def amount_percentage
      return nil if amount.nil?

      (amount * 100).round(2)
    end

    def amount_percentage=(value)
      self.amount = value.present? ? (value.to_f / 100) : nil
    end

    # Countries and states are addressed by their codes across the v3 API —
    # neither model carries a prefixed id, and the codes are what a merchant
    # recognises. The numeric FKs stay writable for internal callers.
    def country_iso=(value)
      self.country = value.present? ? Spree::Country.by_iso(value) : nil
    end

    # Resolved in a callback rather than here: state abbreviations repeat across
    # countries, so the lookup needs the country — and a JSON body can name the
    # state before the country.
    def state_code=(value)
      @state_code_input = value
    end

    # The rates that tax a sale delivered to this address.
    #
    # @param address [Spree::Address, nil]
    # @return [ActiveRecord::Relation<Spree::TaxRate>]
    def self.match(address)
      return none if address.nil?

      for_address(address)
    end

    # The included-in-price rate to back out of a gross price.
    #
    # @param options [Hash] +:country+ (or +:address+) and +:tax_category+
    # @return [BigDecimal] 0 when the jurisdiction or category is unknown
    def self.included_tax_amount_for(options)
      country = options[:country] || options[:address]&.country
      return 0 unless country && options[:tax_category]

      scope = options[:address] ? for_address(options[:address]) : for_country(country)
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

    def resolve_state_code
      return unless defined?(@state_code_input)

      self.state = @state_code_input.blank? ? nil : Spree::State.where(country_id: country_id).find_by(abbr: @state_code_input)
      remove_instance_variable(:@state_code_input)
    end

    # A state-level rate whose state sits in another country would never match
    # any address — the two columns have to agree.
    def state_belongs_to_country
      return if state.nil? || country.nil? || state.country_id == country_id

      errors.add(:state, :invalid)
    end

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
