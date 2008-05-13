require File.dirname(__FILE__) + '/payflow_nv/payflow_nv_common_api'
require File.dirname(__FILE__) + '/payflow_nv/payflow_express_nv_response'
require File.dirname(__FILE__) + '/paypal_express_common'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayflowExpressNvGateway < Gateway
      include PayflowNvCommonAPI
      include PaypalExpressCommon

      self.test_redirect_url = 'https://test-expresscheckout.paypal.com/cgi-bin/webscr?cmd=_express-checkout&token='
      self.homepage_url = 'https://www.paypal.com/cgi-bin/webscr?cmd=xpt/merchant/ExpressCheckoutIntro-outside'
      self.display_name = 'PayPal Express Checkout'

      ACTIONS = {
        :set_express_checkout => 'S',
        :get_express_checkout => 'G',
        :do_express_checkout => 'D'
      }
      
      def authorize(money, options = {})
        requires!(options, :token, :payer_id)

        post = {}
        add_transaction_details(post, :do_express_checkout)

        commit(:authorization, post)
      end

      def purchase(money, options = {})
        requires!(options, :token, :payer_id)

        post = {}
        add_transaction_details(post, :do_express_checkout)

        commit(:purchase, post)
      end

      def credit(money, identification, options = {})
        request = build_reference_request(:credit, money, identification, options)
        commit(request)
      end

      def setup_authorization(money, options = {})
        requires!(options, :return_url, :cancel_return_url)

        post = {}

        add_transaction_details(post, :set_express_checkout)
        add_return_urls(post, options)
        add_addresses(post, options)
        add_customer_data(post, options)
        add_invoice(post, options)
        add_amount(post, money, options)

        commit(:authorization, post)
      end

      def setup_purchase(money, options = {})
        requires!(options, :return_url, :cancel_return_url)

        post = {}

        add_transaction_details(post, :set_express_checkout)
        add_return_urls(post, options)
        add_addresses(post, options)
        add_customer_data(post, options)
        add_invoice(post, options)
        add_amount(post, money, options)

        commit(:purchase, post)
      end

      # How to deal with this?
      def details_for(token)
        post = {}

        add_transaction_details(post, :get_express_checkout)
        add_token(post, token)

        commit(:authorization, post)
      end

      private
      def add_paypal_action(post, action)
        post[:action] = ACTIONS[action]
      end

      def add_token(post, token)
        post[:token] = token
      end

      def add_transaction_details(post, action)
        add_paypal_action(post, action)
        post[:tender] = TENDERS[:paypal]
      end

      def add_return_urls(post, options)
        post[:returnurl] = options[:return_url]
        post[:cancelurl] = options[:cancel_return_url]
      end

      def add_buyer_details(post, options)
        post[:token] = options[:token]
      end

      #def build_setup_request(action, money, options)
      #  xml = Builder::XmlMarkup.new :indent => 2
      #  xml.tag! 'SetExpressCheckoutReq', 'xmlns' => PAYPAL_NAMESPACE do
      #    xml.tag! 'SetExpressCheckoutRequest', 'xmlns:n2' => EBAY_NAMESPACE do
      #      xml.tag! 'n2:Version', API_VERSION
      #      xml.tag! 'n2:SetExpressCheckoutRequestDetails' do
      #        xml.tag! 'n2:PaymentAction', action
      #        xml.tag! 'n2:OrderTotal', amount(money).to_f.zero? ? amount(100) : amount(money), 'currencyID' => options[:currency] || currency(money)
      #        if options[:max_amount]
      #          xml.tag! 'n2:MaxAmount', amount(options[:max_amount]), 'currencyID' => options[:currency] || currency(options[:max_amount])
      #        end
      #        add_address(xml, 'n2:Address', options[:shipping_address] || options[:address])
      #        xml.tag! 'n2:AddressOverride', options[:address_override] ? '1' : '0'
      #        xml.tag! 'n2:NoShipping', options[:no_shipping] ? '1' : '0'
      #        xml.tag! 'n2:ReturnURL', options[:return_url]
      #        xml.tag! 'n2:CancelURL', options[:cancel_return_url]
      #        xml.tag! 'n2:IPAddress', options[:ip]
      #        xml.tag! 'n2:OrderDescription', options[:description]
      #        xml.tag! 'n2:BuyerEmail', options[:email] unless options[:email].blank?
      #        xml.tag! 'n2:InvoiceID', options[:order_id]
      #
      #        # Customization of the payment page
      #        xml.tag! 'n2:PageStyle', options[:page_style] unless options[:page_style].blank?
      #        xml.tag! 'n2:cpp-image-header', options[:header_image] unless options[:header_image].blank?
      #        xml.tag! 'n2:cpp-header-back-color', options[:header_background_color] unless options[:header_background_color].blank?
      #        xml.tag! 'n2:cpp-header-border-color', options[:header_border_color] unless options[:header_border_color].blank?
      #        xml.tag! 'n2:cpp-payflow-color', options[:background_color] unless options[:background_color].blank?
      #
      #        xml.tag! 'n2:LocaleCode', options[:locale] unless options[:locale].blank?
      #      end
      #    end
      #  end

      #  xml.target!
      #end

      #def build_sale_or_authorization_request(action, money, options)
      #  currency_code = options[:currency] || currency(money)
      #
      #  xml = Builder::XmlMarkup.new :indent => 2
      #  xml.tag! 'DoExpressCheckoutPaymentReq', 'xmlns' => PAYPAL_NAMESPACE do
      #    xml.tag! 'DoExpressCheckoutPaymentRequest', 'xmlns:n2' => EBAY_NAMESPACE do
      #      xml.tag! 'n2:Version', API_VERSION
      #      xml.tag! 'n2:DoExpressCheckoutPaymentRequestDetails' do
      #        xml.tag! 'n2:PaymentAction', action
      #        xml.tag! 'n2:Token', options[:token]
      #        xml.tag! 'n2:PayerID', options[:payer_id]
      #        xml.tag! 'n2:PaymentDetails' do
      #          xml.tag! 'n2:OrderTotal', amount(money), 'currencyID' => currency_code
      #
      #          # All of the values must be included together and add up to the order total
      #          if [:subtotal, :shipping, :handling, :tax].all?{ |o| options.has_key?(o) }
      #            xml.tag! 'n2:ItemTotal', amount(options[:subtotal]), 'currencyID' => currency_code
      #            xml.tag! 'n2:ShippingTotal', amount(options[:shipping]),'currencyID' => currency_code
      #            xml.tag! 'n2:HandlingTotal', amount(options[:handling]),'currencyID' => currency_code
      #            xml.tag! 'n2:TaxTotal', amount(options[:tax]), 'currencyID' => currency_code
      #          end
      #
      #          xml.tag! 'n2:NotifyURL', options[:notify_url]
      #          xml.tag! 'n2:ButtonSource', application_id.to_s.slice(0,32) unless application_id.blank?
      #        end
      #      end
      #    end
      #  end

      #  xml.target!
      #end

      def build_response(success, message, response, options = {})
        PayflowExpressNvResponse.new(success, message, response, options)
      end
    end
  end
end

