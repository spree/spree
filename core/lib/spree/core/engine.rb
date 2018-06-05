module Spree
  module Core
    class Engine < ::Rails::Engine
      Environment = Struct.new(:calculators, :preferences, :payment_methods, :adjusters, :stock_splitters, :promotions, :line_item_comparison_hooks)
      SpreeCalculators = Struct.new(:shipping_methods, :tax_rates, :promotion_actions_create_adjustments, :promotion_actions_create_item_adjustments)
      PromoEnvironment = Struct.new(:rules, :actions)
      isolate_namespace Spree
      engine_name 'spree'

      rake_tasks do
        load File.join(root, 'lib', 'tasks', 'exchanges.rake')
      end

      initializer 'spree.environment', before: :load_config_initializers do |app|
        app.config.spree = Environment.new(SpreeCalculators.new, Spree::AppConfiguration.new)
        Spree::Config = app.config.spree.preferences
      end

      initializer 'spree.register.calculators' do |app|
        app.config.spree.calculators.shipping_methods = [
          Spree::Calculator::Shipping::FlatPercentItemTotal,
          Spree::Calculator::Shipping::FlatRate,
          Spree::Calculator::Shipping::FlexiRate,
          Spree::Calculator::Shipping::PerItem,
          Spree::Calculator::Shipping::PriceSack
        ]

        app.config.spree.calculators.tax_rates = [
          Spree::Calculator::DefaultTax
        ]
      end

      initializer 'spree.register.stock_splitters', before: :load_config_initializers do |app|
        app.config.spree.stock_splitters = [
          Spree::Stock::Splitter::ShippingCategory,
          Spree::Stock::Splitter::Backordered
        ]
      end

      initializer 'spree.register.line_item_comparison_hooks', before: :load_config_initializers do |app|
        app.config.spree.line_item_comparison_hooks = Set.new
      end

      initializer 'spree.register.payment_methods', after: 'acts_as_list.insert_into_active_record' do |app|
        app.config.spree.payment_methods = [
          Spree::Gateway::Bogus,
          Spree::Gateway::BogusSimple,
          Spree::PaymentMethod::Check,
          Spree::PaymentMethod::StoreCredit
        ]
      end

      initializer 'spree.register.adjustable_adjusters' do |app|
        app.config.spree.adjusters = [
          Spree::Adjustable::Adjuster::Promotion,
          Spree::Adjustable::Adjuster::Tax
        ]
      end

      # We need to define promotions rules here so extensions and existing apps
      # can add their custom classes on their initializer files
      initializer 'spree.promo.environment' do |app|
        app.config.spree.promotions = PromoEnvironment.new
        app.config.spree.promotions.rules = []
      end

      initializer 'spree.promo.register.promotion.calculators' do |app|
        app.config.spree.calculators.promotion_actions_create_adjustments = [
          Spree::Calculator::FlatPercentItemTotal,
          Spree::Calculator::FlatRate,
          Spree::Calculator::FlexiRate,
          Spree::Calculator::TieredPercent,
          Spree::Calculator::TieredFlatRate
        ]

        app.config.spree.calculators.promotion_actions_create_item_adjustments = [
          Spree::Calculator::PercentOnLineItem,
          Spree::Calculator::FlatRate,
          Spree::Calculator::FlexiRate
        ]
      end

      # Promotion rules need to be evaluated on after initialize otherwise
      # Spree.user_class would be nil and users might experience errors related
      # to malformed model associations (Spree.user_class is only defined on
      # the app initializer)
      config.after_initialize do
        Rails.application.config.spree.promotions.rules.concat [
          Spree::Promotion::Rules::ItemTotal,
          Spree::Promotion::Rules::Product,
          Spree::Promotion::Rules::User,
          Spree::Promotion::Rules::FirstOrder,
          Spree::Promotion::Rules::UserLoggedIn,
          Spree::Promotion::Rules::OneUsePerUser,
          Spree::Promotion::Rules::Taxon,
          Spree::Promotion::Rules::OptionValue,
          Spree::Promotion::Rules::Country
        ]
      end

      initializer 'spree.promo.register.promotions.actions' do |app|
        app.config.spree.promotions.actions = [
          Promotion::Actions::CreateAdjustment,
          Promotion::Actions::CreateItemAdjustments,
          Promotion::Actions::CreateLineItems,
          Promotion::Actions::FreeShipping]
      end

      # filter sensitive information during logging
      initializer 'spree.params.filter' do |app|
        app.config.filter_parameters += [
          :password,
          :password_confirmation,
          :number,
          :verification_value]
      end

      initializer 'spree.core.checking_migrations' do
        Migrations.new(config, engine_name).check
      end

      config.to_prepare do
        # Ensure spree locale paths are present before decorators
        I18n.load_path.unshift(*(Dir.glob(
          File.join(
            File.dirname(__FILE__), '../../../config/locales', '*.{rb,yml}'
          )
        ) - I18n.load_path))

        # Load application's model / class decorators
        Dir.glob(File.join(File.dirname(__FILE__), '../../../app/**/*_decorator*.rb')) do |c|
          Rails.configuration.cache_classes ? require(c) : load(c)
        end
      end
    end
  end
end

require 'spree/core/routes'
require 'spree/core/components'
