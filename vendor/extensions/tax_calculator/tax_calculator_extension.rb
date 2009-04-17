# Uncomment this if you reference any of your controllers in activate
require_dependency 'application'

class TaxCalculatorExtension < Spree::Extension
  version "1.0"
  description "Provides basic tax calculation functionality using the contents and shipping destination of the order."

  def activate
    # Mixin the payment_gateway method into the base controller so it can be accessed by the checkout process, etc.
    Order.class_eval do
      include Spree::TaxCalculator
      Order.state_machines['state'].after_transition(:to => 'creditcard_payment', :do => lambda {|order| order.update_attribute(:tax_amount, order.calculate_tax)})
    end
    Admin::ConfigurationsController.class_eval do
      before_filter :add_tax_rate_links, :only => :index
      def add_tax_rate_links
        @extension_links << {:link => admin_tax_rates_path, :link_text => t("ext_tax_calculator_tax_rates"), :description => t("ext_tax_calculator_tax_rates_description")}
        @extension_links << {:link => admin_tax_settings_path, :link_text => t("ext_tax_calculator_tax_settings"), :description => t("ext_tax_calculator_tax_settings_description")}        
      end
    end
    
    ProductsHelper.class_eval do
      # overrides the original product_price helper to include VAT if applicable
      def product_price(product_or_variant, options={})
        options.assert_valid_keys(:format_as_currency, :show_vat_text)
        options.reverse_merge! :format_as_currency => true, :show_vat_text => Spree::Tax::Config[:show_price_inc_vat]

        amount = product_or_variant.is_a?(Product) ? product_or_variant.master_price : product_or_variant.price
        amount += Spree::VatCalculator.calculate_tax_on(product_or_variant) if Spree::Tax::Config[:show_price_inc_vat]
        options.delete(:format_as_currency) ? format_price(amount, options) : amount
      end
      
      # overrides the original format_price helper to include the VAT label if applicable
      def format_price(price, options={})
        options.assert_valid_keys(:show_vat_text)
        options.reverse_merge! :show_vat_text => Spree::Tax::Config[:show_price_inc_vat]
        options[:show_vat_text]  ?  number_to_currency(price) + ' (inc. VAT)' : number_to_currency(price)
      end
    end
  end
end