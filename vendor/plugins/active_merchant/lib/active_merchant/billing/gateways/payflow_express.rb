require File.dirname(__FILE__) + '/payflow/payflow_common_api'
require File.dirname(__FILE__) + '/payflow/payflow_express_response'
require File.dirname(__FILE__) + '/paypal_express_common'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayflowExpressGateway < Gateway 
      include PayflowCommonAPI
      include PaypalExpressCommon
      
      self.test_redirect_url = 'https://test-expresscheckout.paypal.com/cgi-bin/webscr?cmd=_express-checkout&token='      
      self.homepage_url = 'https://www.paypal.com/cgi-bin/webscr?cmd=xpt/merchant/ExpressCheckoutIntro-outside'
      self.display_name = 'PayPal Express Checkout'
      
      def authorize(money, options = {})
        requires!(options, :token, :payer_id)
        request = build_sale_or_authorization_request('Authorization', money, options)
        commit(request)
      end
      
      def purchase(money, options = {})        
        requires!(options, :token, :payer_id)
        request = build_sale_or_authorization_request('Sale', money, options)
        commit(request)
      end
      
      def credit(money, identification, options = {})
        request = build_reference_request(:credit, money, identification, options)
        commit(request)
      end        

      def setup_authorization(money, options = {})
        requires!(options, :return_url, :cancel_return_url)
        
        request = build_setup_express_sale_or_authorization_request('Authorization', money, options)
        commit(request)
      end
      
      def setup_purchase(money, options = {})
        requires!(options, :return_url, :cancel_return_url)
        
        request = build_setup_express_sale_or_authorization_request('Sale', money, options)
        commit(request)
      end
      
      def details_for(token)
        request = build_get_express_details_request(token)
        commit(request)
      end
      
      private
      def build_get_express_details_request(token)
        xml = Builder::XmlMarkup.new :indent => 2  
        xml.tag! 'GetExpressCheckout' do
          xml.tag! 'Authorization' do
            xml.tag! 'PayData' do  
              xml.tag! 'Tender' do
                xml.tag! 'PayPal' do
                  xml.tag! 'Token', token
                end
              end
            end
          end
        end
        xml.target!
      end
      
      def build_setup_express_sale_or_authorization_request(action, money, options = {})
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'SetExpressCheckout' do
          xml.tag! action do
            xml.tag! 'PayData' do
              xml.tag! 'Invoice' do
                xml.tag! 'CustIP', options[:ip] unless options[:ip].blank?
                xml.tag! 'InvNum', options[:order_id] unless options[:order_id].blank?
                xml.tag! 'Description', options[:description] unless options[:description].blank?
            
                billing_address = options[:billing_address] || options[:address]
                add_address(xml, 'BillTo', billing_address, options) if billing_address
                add_address(xml, 'ShipTo', options[:shipping_address], options) if options[:shipping_address]
                
                xml.tag! 'TotalAmt', amount(money), 'Currency' => options[:currency] || currency(money)
              end
              
              xml.tag! 'Tender' do
                add_paypal_details(xml, options)
              end
            end
          end
        end
        xml.target!
      end
      
      def build_sale_or_authorization_request(action, money, options) 
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'DoExpressCheckout' do
          xml.tag! action do
            xml.tag! 'PayData' do
              xml.tag! 'Invoice' do 
                xml.tag! 'TotalAmt', amount(money), 'Currency' => options[:currency] || currency(money)
              end
              xml.tag! 'Tender' do
                add_paypal_details xml, options
              end
            end
          end
        end
        xml.target!
      end
      
      def add_paypal_details(xml, options)
         xml.tag! 'PayPal' do
          xml.tag! 'EMail', options[:email] unless options[:email].blank?
          xml.tag! 'ReturnURL', options[:return_url] unless options[:return_url].blank?
          xml.tag! 'CancelURL', options[:cancel_return_url] unless options[:cancel_return_url].blank?
          xml.tag! 'NotifyURL', options[:notify_url] unless options[:notify_url].blank?
          xml.tag! 'PayerID', options[:payer_id] unless options[:payer_id].blank?
          xml.tag! 'Token', options[:token] unless options[:token].blank?
          xml.tag! 'NoShipping', options[:no_shipping] ? '1' : '0'
          xml.tag! 'AddressOverride', options[:address_override] ? '1' : '0'
          xml.tag! 'ButtonSource', application_id.to_s.slice(0,32) unless application_id.blank? 
          
          # Customization of the payment page
          xml.tag! 'PageStyle', options[:page_style] unless options[:page_style].blank?
          xml.tag! 'HeaderImage', options[:header_image] unless options[:header_image].blank?
          xml.tag! 'HeaderBackColor', options[:header_background_color] unless options[:header_background_color].blank?
          xml.tag! 'HeaderBorderColor', options[:header_border_color] unless options[:header_border_color].blank?
          xml.tag! 'PayflowColor', options[:background_color] unless options[:background_color].blank?
        end
      end
      
      def build_response(success, message, response, options = {})
        PayflowExpressResponse.new(success, message, response, options)
      end
    end
  end
end

