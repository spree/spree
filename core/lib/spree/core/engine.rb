module Spree
  module Core
    class Engine < Rails::Engine
      isolate_namespace Spree
      engine_name 'spree_core'

      config.autoload_paths += %W(#{config.root}/lib)

      def self.activate
      end

      config.to_prepare &method(:activate).to_proc

      config.after_initialize do
        ActiveSupport::Notifications.subscribe(/^spree\./) do |*args|
          event_name, start_time, end_time, id, payload = args
          Activator.active.event_name_starts_with(event_name).each do |activator|
            activator.activate(payload)
          end
        end
      end

      initializer "spree.environment" do |app|
        app.config.spree = Spree::Environment.new
      end

      initializer "spree.register.calculators" do |app|
        app.config.spree.calculators.shipping_methods = [
            Calculator::FlatPercentItemTotal,
            Calculator::FlatRate,
            Calculator::FlexiRate,
            Calculator::PerItem,
            Calculator::PriceBucket]

         app.config.spree.calculators.tax_rates = [
            Calculator::SalesTax,
            Calculator::Vat]
      end

      initializer "spree.register.payment_methods" do |app|
        app.config.spree.payment_methods = [
            Gateway::Bogus,
            Gateway::AuthorizeNet,
            Gateway::AuthorizeNetCim,
            Gateway::Eway,
            Gateway::Linkpoint,
            Gateway::PayPal,
            Gateway::SagePay,
            Gateway::Beanstream,
            Gateway::Braintree,
            PaymentMethod::Check ]
      end

      # filter sensitive information during logging
      initializer "spree.params.filter" do |app|
        app.config.filter_parameters += [:password, :password_confirmation, :number]
      end

      # sets the manifests / assets to be precompiled
      initializer "spree.assets.precompile", :group => :assets do |app|
        app.config.assets.precompile += ['store/all.*', 'admin/all.*', 'admin/spree_dash.*', 'admin/orders/edit_form.js', 'jqPlot/excanvas.min.js', 'admin/images/new.js']
      end

      initializer "spree.asset.pipeline" do |app|
        app.config.assets.debug = false
      end

      # turn off asset debugging since that kills performance in development mode
      initializer "spree.asset.pipeline" do |app|
        app.config.assets.debug = false
      end
    end
  end
end
