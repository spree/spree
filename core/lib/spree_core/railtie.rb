module SpreeCore
  class Engine < Rails::Engine
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
          Spree::Calculator::FlatPercentItemTotal,
          Spree::Calculator::FlatRate,
          Spree::Calculator::FlexiRate,
          Spree::Calculator::PerItem,
          Spree::Calculator::PriceBucket]

       app.config.spree.calculators.tax_rates = [
          Spree::Calculator::SalesTax,
          Spree::Calculator::Vat]
    end

    initializer "spree.register.payment_methods" do |app|
      app.config.spree.payment_methods = [
          Spree::Gateway::Bogus,
          Spree::Gateway::AuthorizeNet,
          Spree::Gateway::AuthorizeNetCim,
          Spree::Gateway::Eway,
          Spree::Gateway::Linkpoint,
          Spree::Gateway::PayPal,
          Spree::Gateway::SagePay,
          Spree::Gateway::Beanstream,
          Spree::Gateway::Braintree,
          Spree::PaymentMethod::Check ]
    end

    # filter sensitive information during logging
    initializer "spree.params.filter" do |app|
      app.config.filter_parameters += [:password, :password_confirmation, :number]
    end

    # sets the manifests / assets to be precompiled
    initializer "spree.assets.precompile", :group => :assets do |app|
      app.config.assets.precompile += ['store/all.*', 'admin/all.*', 'admin/spree_dash.*', 'admin/orders/edit_form.js', 'jqPlot/excanvas.min.js', 'admin/images/new.js']
    end

    # turn off asset debugging since that kills performance in development mode
    initializer "spree.asset.pipeline" do |app|
      app.config.assets.debug = false
    end


  end
end
