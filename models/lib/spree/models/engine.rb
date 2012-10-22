module Spree
  def self.table_name_prefix
    "spree_"
  end
  module Models
    class Engine < ::Rails::Engine
      engine_name 'spree_models'

      config.autoload_paths += %W(#{config.root}/lib)

      config.after_initialize do
        ActiveSupport::Notifications.subscribe(/^spree\./) do |*args|
          event_name, start_time, end_time, id, payload = args
          Activator.active.event_name_starts_with(event_name).each do |activator|
            payload[:event_name] = event_name
            activator.activate(payload)
          end
        end
      end

      initializer "spree.environment", :before => :load_config_initializers do |app|
        app.config.spree = Spree::Models::Environment.new
        Spree::Config = app.config.spree.preferences #legacy access
      end

      initializer "spree.load_preferences", :before => "spree.environment" do
        ::ActiveRecord::Base.send :include, Spree::Preferences::Preferable
      end

      initializer "spree.register.calculators" do |app|
        app.config.spree.calculators.shipping_methods = [
            Spree::Calculator::FlatPercentItemTotal,
            Spree::Calculator::FlatRate,
            Spree::Calculator::FlexiRate,
            Spree::Calculator::PerItem,
            Spree::Calculator::PriceSack]

         app.config.spree.calculators.tax_rates = [
            Spree::Calculator::DefaultTax]
      end

      initializer "spree.register.payment_methods" do |app|
        app.config.spree.payment_methods = [
            Spree::Gateway::Bogus,
            Spree::Gateway::BogusSimple,
            Spree::PaymentMethod::Check ]
      end

      initializer "spree.mail.settings" do |app|
        if Spree::MailMethod.table_exists?
          Spree::Models::MailSettings.init
          Mail.register_interceptor(Spree::Models::MailInterceptor)
        end
      end
    end
  end
end
