require_library_or_gem 'action_pack'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module ActionViewHelper
        # This helper allows the usage of different payment integrations
        # through a single form helper.  Payment integrations are the
        # type of service where the user is redirected to the secure
        # site of the service, like Paypal or Chronopay.
        #
        # The helper creates a scope around a payment service helper
        # which provides the specific mapping for that service.
        # 
        #  <% payment_service_for 1000, 'paypalemail@mystore.com',
        #                               :amount => 50.00, 
        #                               :currency => 'CAD', 
        #                               :service => :paypal, 
        #                               :html => { :id => 'payment-form' } do |service| %>
        #
        #    <% service.customer :first_name => 'Cody',
        #                       :last_name => 'Fauser',
        #                       :phone => '(555)555-5555',
        #                       :email => 'codyfauser@gmail.com' %>
        #
        #    <% service.billing_address :city => 'Ottawa',
        #                              :address1 => '21 Snowy Brook Lane',
        #                              :address2 => 'Apt. 36',
        #                              :state => 'ON',
        #                              :country => 'CA',
        #                              :zip => 'K1J1E5' %>
        #
        #    <% service.invoice '#1000' %>
        #    <% service.shipping '0.00' %>
        #    <% service.tax '0.00' %>
        #
        #    <% service.notify_url url_for(:only_path => false, :action => 'notify') %>
        #    <% service.return_url url_for(:only_path => false, :action => 'done') %>
        #    <% service.cancel_return_url 'http://mystore.com' %>
        #  <% end %>
        #
        def payment_service_for(order, account, options = {}, &proc)          
          raise ArgumentError, "Missing block" unless block_given?

          integration_module = ActiveMerchant::Billing::Integrations.const_get(options.delete(:service).to_s.classify)

          if ignore_binding?
            concat(form_tag(integration_module.service_url, options.delete(:html) || {}))
          else
            concat(form_tag(integration_module.service_url, options.delete(:html) || {}), proc.binding)
          end
          result = "\n"
          
          service_class = integration_module.const_get('Helper')
          service = service_class.new(order, account, options)
          yield service
          
          result << service.form_fields.collect do |field, value|
            hidden_field_tag(field, value)
          end.join("\n")

          result << "\n"
          result << '</form>' 

          if ignore_binding?
            concat(result)
          else
            concat(result, proc.binding)
          end
        end
        
        private
        def ignore_binding?
          ActionPack::VERSION::MAJOR >= 2 && ActionPack::VERSION::MINOR >= 2
        end
      end
    end
  end
end
