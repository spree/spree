class Calculator::SalesTax < Calculator

  def self.description
    I18n.t("sales_tax")
  end
    
  def self.register
    super
    TaxRate.register_calculator(self)
  end
  
  def self.calculate_tax(order, rates)
    ActiveSupport::Deprecation.warn("please use Calculator::SalesTax#compute instead", caller)

    return 0 if rates.empty?
    # note: there is a bug with associations in rails 2.1 model caching so we're using this hack
    # (see http://rails.lighthouseapp.com/projects/8994/tickets/785-caching-models-fails-in-development)
    cache_hack = rates.first.respond_to?(:tax_category_id)
            
    taxable_totals = {}
    order.line_items.each do |line_item|
      next unless tax_category = line_item.variant.product.tax_category
      next unless rate = rates.find { | sales_rate | sales_rate.tax_category_id == tax_category.id } if cache_hack
      next unless rate = rates.find { | sales_rate | sales_rate.tax_category == tax_category } unless cache_hack

      taxable_totals[tax_category] ||= 0
      taxable_totals[tax_category] += line_item.total
    end

    return 0 if taxable_totals.empty?
    tax = 0
    rates.each do |rate|
      tax_category = rate.tax_category unless cache_hack
      tax_category = TaxCategory.find(rate.tax_category_id) if cache_hack
      next unless taxable_total = taxable_totals[tax_category]
      tax += taxable_total * rate.amount
    end
    tax
  end

  def compute(order)
    rate = self.calculable
    line_items = order.line_items.select { |i| i.product.tax_category == rate.tax_category }
    line_items.inject(0) {|sum, line_item|
      sum += line_item.total * rate.amount
    }
  end
end