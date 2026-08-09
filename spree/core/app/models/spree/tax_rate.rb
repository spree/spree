module Spree
  # Pure tax configuration read by the internal tax provider
  # (Spree::TaxProvider::Internal). Since 6.0 tax rates have no write path of
  # their own — TaxLine rows are written exclusively by Spree.tax_provider.
  class TaxRate < Spree.base_class
    has_prefix_id :tax

    acts_as_paranoid

    include Spree::HasCustomFields
    include Spree::Metadata

    with_options inverse_of: :tax_rates do
      belongs_to :zone, class_name: 'Spree::Zone', optional: true
      belongs_to :tax_category,
                 class_name: 'Spree::TaxCategory'
    end

    has_many :tax_lines, class_name: 'Spree::TaxLine', dependent: :nullify

    with_options presence: true do
      validates :amount, numericality: { allow_nil: true }
      validates :tax_category, :name
    end

    scope :by_zone, ->(zone) { where(zone_id: zone.id) }
    scope :potential_rates_for_zone,
          ->(zone) do
            where(zone_id: Spree::Zone.potential_matching_zones(zone).pluck(:id))
          end
    scope :for_default_zone,
          -> { potential_rates_for_zone(Spree::Zone.default_tax) }
    scope :for_tax_category,
          ->(category) { where(tax_category_id: category.try(:id)) }
    scope :included_in_price, -> { where(included_in_price: true) }

    self.whitelisted_ransackable_attributes = %w[amount zone_id tax_category_id included_in_price name]

    # Virtual attribute for percentage display in admin forms
    def amount_percentage
      return nil if amount.nil?

      (amount * 100).round(2)
    end

    def amount_percentage=(value)
      self.amount = value.present? ? (value.to_f / 100) : nil
    end

    # Gets the array of TaxRates appropriate for the specified tax zone
    def self.match(order_tax_zone)
      return [] unless order_tax_zone

      potential_rates_for_zone(order_tax_zone)
    end

    def self.included_tax_amount_for(options)
      return 0 unless options[:tax_zone] && options[:tax_category]

      potential_rates_for_zone(options[:tax_zone]).
        included_in_price.
        for_tax_category(options[:tax_category]).
        sum(:amount)
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
