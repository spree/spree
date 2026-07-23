module Spree
  class TaxRate < Spree.base_class
    has_prefix_id :tax

    acts_as_paranoid

    include Spree::CalculatedAdjustments
    include Spree::Metafields
    include Spree::Metadata

    with_options inverse_of: :tax_rates do
      belongs_to :zone, class_name: 'Spree::Zone', optional: true
      belongs_to :tax_category,
                 class_name: 'Spree::TaxCategory'
    end

    # No dependent option: tax lines outlive a (soft-)deleted rate — completed
    # orders keep their frozen lines; incomplete orders shed them on the next
    # recalculation when the rate stops matching.
    has_many :tax_lines, class_name: 'Spree::TaxLine', inverse_of: :tax_rate

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

    # Pre-tax amounts must be stored so that we can calculate
    # correct rate amounts in the future. For example:
    # https://github.com/spree/spree/issues/4318#issuecomment-34723428
    #
    # Written from the same live basis tax is computed on: the amount net of
    # ALL discounts (item-level and distributed whole-order shares), with
    # included taxes divided out. Refunds (Calculator::Returns::
    # DefaultRefundAmount) read this column directly.
    def self.store_pre_tax_amount(item, rates)
      pre_tax_amount = item.taxable_basis

      included_rates = rates.select(&:included_in_price)
      if included_rates.any?
        pre_tax_amount /= (1 + included_rates.sum(&:amount))
      end

      item.update_column(:pre_tax_amount, pre_tax_amount)
    end

    # Refreshes the items' TaxLine rows from the rates matching the order's
    # tax zone: upserts a line per applicable rate, drops lines whose rate no
    # longer applies (zone change, category change, zeroed amount). Interim
    # entry point — 6.0-tax-provider.md replaces it with the provider.
    def self.adjust(order, items)
      return if items.none?

      rates = match(order.tax_zone)
      tax_category_ids = rates.map(&:tax_category_id)

      relevant_items = items.select do |item|
        tax_category_ids.include?(item.tax_category_id)
      end

      relevant_items.each do |item|
        relevant_rates = rates.select do |rate|
          rate.tax_category_id == item.tax_category_id
        end
        store_pre_tax_amount(item, relevant_rates)
        item.tax_lines.where.not(tax_rate_id: relevant_rates.map(&:id)).destroy_all
        relevant_rates.each do |rate|
          rate.adjust(order, item)
        end
      end

      # items without any applicable rate shed their tax lines and reset pre_tax
      (items - relevant_items).each do |item|
        store_pre_tax_amount(item, [])
        item.tax_lines.destroy_all
      end
    end

    def self.included_tax_amount_for(options)
      return 0 unless options[:tax_zone] && options[:tax_category]

      potential_rates_for_zone(options[:tax_zone]).
        included_in_price.
        for_tax_category(options[:tax_category]).
        sum(:amount)
    end

    # Upserts this rate's TaxLine on the item; a zero amount removes the line
    # instead — tax lines only exist while tax is owed.
    def adjust(order, item)
      amount = compute_amount(item)
      tax_line = item.tax_lines.find_or_initialize_by(tax_rate: self, order: order)

      if amount.zero?
        tax_line.destroy! if tax_line.persisted?
        return
      end

      tax_line.amount = amount
      tax_line.included = included_in_price
      tax_line.label = label
      tax_line.save!
    end

    def compute_amount(item)
      compute(item)
    end

    def included?
      included_in_price
    end

    def additional?
      !included_in_price
    end

    private

    def label
      Spree.t included_in_price? ? :including_tax : :excluding_tax,
              scope: 'adjustment_labels.tax_rates',
              name: name.presence || tax_category.name,
              amount: amount_for_label
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
