class Calculator::Vat < Calculator

  def self.description
    I18n.t("vat")
  end

  def self.register
    super
    TaxRate.register_calculator(self)
  end

  # list the vat rates for the default country
  # TODO: Refactor this method after integrating #54 to use default address
  def self.default_rates
    return [] unless zone_member = ZoneMember.find(:first, :conditions => ["zoneable_id = #{Spree::Config[:default_country_id]} AND zoneable_type = 'Country'"])
    TaxRate.find_all_by_zone_id_and_tax_type(zone_member.zone, TaxRate::TaxType::VAT)
  end

  def self.calculate_tax(order, rates=default_rates)
    ActiveSupport::Deprecation.warn("please use Calculator::Vat#compute instead", caller)

    return 0 if rates.empty?
    # note: there is a bug with associations in rails 2.1 model caching so we're using this hack
    # (see http://rails.lighthouseapp.com/projects/8994/tickets/785-caching-models-fails-in-development)
    cache_hack = rates.first.respond_to?(:tax_category_id)
  
    taxable_totals = {}
    order.line_items.each do |line_item|
      next unless tax_category = line_item.variant.product.tax_category
      next unless rate = rates.find { | vat_rate | vat_rate.tax_category_id == tax_category.id } if cache_hack
      next unless rate = rates.find { | vat_rate | vat_rate.tax_category == tax_category } unless cache_hack
      taxable_totals[tax_category] ||= 0
      taxable_totals[tax_category] += line_item.price * rate.amount * line_item.quantity
    end
    
    return 0 if taxable_totals.empty?
    tax = 0
    taxable_totals.values.each do |total|
      tax += total
    end
    tax
  end

  # TODO: Refactor this method after integrating #54 to use default address
  def self.calculate_tax_on(product_or_variant)
    vat_rates = default_rates

    return 0 if vat_rates.nil?
    return 0 unless tax_category = product_or_variant.is_a?(Product) ? product_or_variant.tax_category : product_or_variant.product.tax_category
    return 0 unless rate = vat_rates.find { | vat_rate | vat_rate.tax_category_id = tax_category.id }

    (product_or_variant.is_a?(Product) ? product_or_variant.master_price : product_or_variant.price) * rate.amount
  end

  # computes vat for line_items associated with order, and tax rate
  def compute(order)
    rate = self.calculable
    line_items = order.line_items.select { |i| i.product.tax_category == rate.tax_category }
    line_items.inject(0) {|sum, line_item|
      sum += (line_item.price * rate.amount * line_item.quantity)
    }    
    # rate = self.calculable
    # line_items = LineItem.find(:all, {
    #     :include => {:variant => :product},
    #     :conditions => ["line_items.order_id = ? AND products.tax_category_id = ?", order.id, rate.tax_category_id]
    # })
    # line_items.inject(0) {|sum, line_item|
    #   sum += line_item.total * rate.amount
    # }
  end
end