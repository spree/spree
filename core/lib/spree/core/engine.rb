module Spree
  module Core
    class Engine < ::Rails::Engine
      isolate_namespace Spree
      engine_name 'spree'

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
        app.config.spree = Spree::Core::Environment.new
        Spree::Config = app.config.spree.preferences #legacy access

        app.config.spree.add_class('promotions')
        app.config.spree.promotions = Spree::Promo::Environment.new
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
          Spree::Core::MailSettings.init
          Mail.register_interceptor(Spree::Core::MailInterceptor)
        end
      end

      initializer 'spree.promo.register.promotion.calculators' do |app|
        app.config.spree.calculators.add_class('promotion_actions_create_adjustments')
        app.config.spree.calculators.promotion_actions_create_adjustments = [
          Spree::Calculator::FlatPercentItemTotal,
          Spree::Calculator::FlatRate,
          Spree::Calculator::FlexiRate,
          Spree::Calculator::PerItem,
          Spree::Calculator::PercentPerItem,
          Spree::Calculator::FreeShipping
        ]
      end

      initializer 'spree.promo.register.promotions.rules' do |app|
        app.config.spree.promotions.rules = [
          Spree::Promotion::Rules::ItemTotal,
          Spree::Promotion::Rules::Product,
          Spree::Promotion::Rules::User,
          Spree::Promotion::Rules::FirstOrder,
          Spree::Promotion::Rules::UserLoggedIn]
      end

      initializer 'spree.promo.register.promotions.actions' do |app|
        app.config.spree.promotions.actions = [Spree::Promotion::Actions::CreateAdjustment,
          Spree::Promotion::Actions::CreateLineItems]
      end
    end
  end
end
