#
# Spree's basic asumtion on taxes is that tax gets applied to prices you see in a shop.
#
# In Europe where vat is used this assumption is wrong. All consumer prices _always include appropriate tax. 
#
# Also spree assumes no tax on shipping costs(wrong) and tax_rates per region (partially wrong, as rates
# also change per product or rather kind of product)
#
# Rather, Vat works like this:
# - product prices shown to cutomers always include apropriate VAT
# - due to this, admins enter vat inclusive prices
# - by law vat must be expressly mentioned in an order statement
# - vat may vary by product kind, ie food 9% , services 16% , rest 23%
#  (this means several rates must/may be configured and instantiated)

# OPEN issues: tax included in coupons

class Calculator::Vat < Calculator

  def self.description
    I18n.t("vat")
  end

  def self.register
    super
    TaxRate.register_calculator(self)
  end

  # list the vat rates for the default country
  def self.default_rates
    origin = Country.find(Spree::Config[:default_country_id])
    calcs = Calculator::Vat.includes(:calculable => :zone).select {
      |vat| vat.calculable.zone.country_list.include?(origin)
    }
    calcs.collect { |calc| calc.calculable }
  end

  def self.calculate_tax_on(product_or_variant)
    vat_rates = default_rates  # maybe better to mark the rate too, for speed
    return 0 if vat_rates.nil? # configuration error
    rate = 0
    product = product_or_variant.class == Product ? product_or_variant : product_or_variant.product
    if tax_category = product.tax_category
      t_rate = vat_rates.find { | vat_rate | vat_rate.tax_category_id == tax_category.id }
      rate = t_rate.amount if t_rate
    end
    if rate == 0
      default_rates.each do |t_rate| 
        rate = t_rate.amount if t_rate.tax_category.is_default
      end
    end
    (product_or_variant.price * rate).round(2, BigDecimal::ROUND_HALF_UP)
  end

  # computes vat for line_items associated with order, and tax rate and 
  # now coupon discounts are taken into account in tax calcs
  def compute(order)
    debug = false
    rate = self.calculable
    puts "#{rate.id} RATE IS #{rate.amount}" if debug
    tax = 0
    if rate.tax_category.is_default and !Spree::Config[ :show_price_inc_vat]
      order.adjustments.each do | adjust |
        next if adjust.originator_type == "TaxRate"
        add = adjust.amount * rate.amount
        puts "Applying default rate to adjustment #{adjust.label} (#{adjust.originator_type} ), sum = #{add}"
        tax += add
      end
    end
    order.line_items.each do  | line_item|
      if line_item.product.tax_category  #only apply this calculator to products assigned this rates category
        next unless line_item.product.tax_category == rate.tax_category
      else
        next unless is_default? # and apply to products with no category, if this is the default rate
        #TODO: though it would be a user error, there may be several rates for the default category
        #      and these would be added up by this. 
      end
      next unless line_item.product.tax_category.tax_rates.include? rate
      puts "COMPUTE for #{line_item.price} is #{ line_item.price * rate.amount} RATE IS #{rate.amount}" if debug
      tax += (line_item.price * rate.amount).round(2, BigDecimal::ROUND_HALF_UP) * line_item.quantity
    end
    tax
  end
end
