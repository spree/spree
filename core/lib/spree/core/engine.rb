require_relative 'dependencies'
require_relative 'configuration'

module Spree
  module Core
    class Engine < ::Rails::Engine
      Environment = Struct.new(:calculators,
                               :preferences,
                               :dependencies,
                               :payment_methods,
                               :adjusters,
                               :stock_splitters,
                               :promotions,
                               :line_item_comparison_hooks,
                               :data_feed_types,
                               :export_types,
                               :taxon_rules,
                               :themes,
                               :theme_layout_sections,
                               :pages,
                               :page_sections,
                               :page_blocks,
                               :reports)
      SpreeCalculators = Struct.new(:shipping_methods, :tax_rates, :promotion_actions_create_adjustments, :promotion_actions_create_item_adjustments)
      PromoEnvironment = Struct.new(:rules, :actions)
      isolate_namespace Spree
      engine_name 'spree'

      rake_tasks do
        load File.join(root, 'lib', 'tasks', 'exchanges.rake')
      end

      initializer 'spree.environment', before: :load_config_initializers do |app|
        app.config.spree = Environment.new(SpreeCalculators.new, Spree::Core::Configuration.new, Spree::Core::Dependencies.new)
        app.config.active_record.yaml_column_permitted_classes ||= []
        app.config.active_record.yaml_column_permitted_classes << [Symbol, BigDecimal, ActiveSupport::HashWithIndifferentAccess]
        Spree::Config = app.config.spree.preferences
        Spree::RuntimeConfig = app.config.spree.preferences # for compatibility
        Spree::Dependencies = app.config.spree.dependencies
        Spree::Deprecation = ActiveSupport::Deprecation.new
      end

      initializer 'spree.register.calculators', before: :after_initialize do |app|
      end

      initializer 'spree.register.stock_splitters', before: :load_config_initializers do |app|
      end

      initializer 'spree.register.line_item_comparison_hooks', before: :load_config_initializers do |app|
        app.config.spree.line_item_comparison_hooks = Set.new
      end

      initializer 'spree.register.payment_methods', after: 'acts_as_list.insert_into_active_record' do |app|
      end

      initializer 'spree.register.adjustable_adjusters' do |app|
      end

      # We need to define promotions rules here so extensions and existing apps
      # can add their custom classes on their initializer files
      initializer 'spree.promo.environment' do |app|
        app.config.spree.promotions = PromoEnvironment.new
        app.config.spree.promotions.rules = []
      end

      initializer 'spree.promo.register.promotion.calculators' do |app|
      end

      # Promotion rules need to be evaluated on after initialize otherwise
      # Spree.user_class would be nil and users might experience errors related
      # to malformed model associations (Spree.user_class is only defined on
      # the app initializer)
      config.after_initialize do
        Rails.application.config.spree.calculators.shipping_methods = [
          Spree::Calculator::Shipping::FlatPercentItemTotal,
          Spree::Calculator::Shipping::FlatRate,
          Spree::Calculator::Shipping::FlexiRate,
          Spree::Calculator::Shipping::PerItem,
          Spree::Calculator::Shipping::PriceSack,
          Spree::Calculator::Shipping::DigitalDelivery,
        ]

        Rails.application.config.spree.calculators.tax_rates = [
          Spree::Calculator::DefaultTax
        ]

        Rails.application.config.spree.stock_splitters = [
          Spree::Stock::Splitter::ShippingCategory,
          Spree::Stock::Splitter::Backordered,
          Spree::Stock::Splitter::Digital
        ]

        Rails.application.config.spree.payment_methods = [
          Spree::Gateway::Bogus,
          Spree::Gateway::BogusSimple,
          Spree::PaymentMethod::Check,
          Spree::PaymentMethod::StoreCredit
        ]

        Rails.application.config.spree.adjusters = [
          Spree::Adjustable::Adjuster::Promotion,
          Spree::Adjustable::Adjuster::Tax
        ]

        Rails.application.config.spree.calculators.promotion_actions_create_adjustments = [
          Spree::Calculator::FlatPercentItemTotal,
          Spree::Calculator::FlatRate,
          Spree::Calculator::FlexiRate,
          Spree::Calculator::TieredPercent,
          Spree::Calculator::TieredFlatRate
        ]

        Rails.application.config.spree.calculators.promotion_actions_create_item_adjustments = [
          Spree::Calculator::PercentOnLineItem,
          Spree::Calculator::FlatRate,
          Spree::Calculator::FlexiRate
        ]

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

        Rails.application.config.spree.promotions.actions = [
          Promotion::Actions::CreateAdjustment,
          Promotion::Actions::CreateItemAdjustments,
          Promotion::Actions::CreateLineItems,
          Promotion::Actions::FreeShipping
        ]

        Rails.application.config.spree.data_feed_types = [
          Spree::DataFeed::Google
        ]

        Rails.application.config.spree.export_types = [
          Spree::Exports::Products,
          Spree::Exports::Orders
        ]

        Rails.application.config.spree.taxon_rules = [
          Spree::TaxonRules::Tag,
          Spree::TaxonRules::AvailableOn,
          Spree::TaxonRules::Sale,
        ]

        Rails.application.config.spree.themes = [
          Spree::Themes::Default
        ]

        Rails.application.config.spree.theme_layout_sections = [
          Spree::PageSections::AnnouncementBar,
          Spree::PageSections::Header,
          Spree::PageSections::Newsletter,
          Spree::PageSections::Footer
        ]

        Rails.application.config.spree.pages = [
          Spree::Pages::Cart,
          Spree::Pages::Post,
          Spree::Pages::TaxonList,
          Spree::Pages::Custom,
          Spree::Pages::ProductDetails,
          Spree::Pages::ShopAll,
          Spree::Pages::Taxon,
          Spree::Pages::Wishlist,
          Spree::Pages::SearchResults,
          Spree::Pages::Checkout,
          Spree::Pages::Password,
          Spree::Pages::Homepage,
          Spree::Pages::Login,
          Spree::Pages::PostList,
          Spree::Pages::Account
        ]

        Rails.application.config.spree.page_sections = [
          Spree::PageSections::FeaturedPosts,
          Spree::PageSections::TaxonGrid,
          Spree::PageSections::ImageWithText,
          Spree::PageSections::FeaturedTaxon,
          Spree::PageSections::CollectionBanner,
          Spree::PageSections::ProductDetails,
          Spree::PageSections::MainPasswordFooter,
          Spree::PageSections::RelatedProducts,
          Spree::PageSections::CustomCode,
          Spree::PageSections::TaxonBanner,
          Spree::PageSections::FeaturedProduct,
          Spree::PageSections::ProductGrid,
          Spree::PageSections::ImageBanner,
          Spree::PageSections::PageTitle,
          Spree::PageSections::MainPasswordHeader,
          Spree::PageSections::PostDetails,
          Spree::PageSections::PostGrid,
          Spree::PageSections::FeaturedTaxons,
          Spree::PageSections::RichText,
          Spree::PageSections::Video,
          Spree::PageSections::Footer,
          Spree::PageSections::Newsletter,
          Spree::PageSections::Header,
          Spree::PageSections::AnnouncementBar
        ]

        Rails.application.config.spree.page_blocks = [
          Spree::PageBlocks::Link,
          Spree::PageBlocks::MegaNav,
          Spree::PageBlocks::MegaNavWithSubcategories,
          Spree::PageBlocks::Subheading,
          Spree::PageBlocks::Heading,
          Spree::PageBlocks::Nav,
          Spree::PageBlocks::Buttons,
          Spree::PageBlocks::Text,
          Spree::PageBlocks::NewsletterForm,
          Spree::PageBlocks::Image,
          Spree::PageBlocks::Products::Title,
          Spree::PageBlocks::Products::Share,
          Spree::PageBlocks::Products::Price,
          Spree::PageBlocks::Products::QuantitySelector,
          Spree::PageBlocks::Products::VariantPicker,
          Spree::PageBlocks::Products::BuyButtons
        ]

        Rails.application.config.spree.reports = [
          Spree::Reports::ProductsPerformance,
          Spree::Reports::SalesTotal
        ]
      end

      initializer 'spree.promo.register.promotions.actions' do |app|
      end

      # filter sensitive information during logging
      initializer 'spree.params.filter' do |app|
        app.config.filter_parameters += [
          :password,
          :password_confirmation,
          :number,
          :verification_value,
          :client_id,
          :client_secret,
          :refresh_token
        ]
      end

      initializer 'spree.core.checking_migrations' do
        Migrations.new(config, engine_name).check
      end

      initializer 'spree.core.assets' do |app|
        if app.config.respond_to?(:assets)
          app.config.assets.paths << root.join('app/javascript')
          app.config.assets.paths << root.join('vendor/javascript')
          app.config.assets.precompile += %w[spree_core_manifest]
        end
      end

      initializer 'spree.core.importmap', before: 'importmap' do |app|
        if app.config.respond_to?(:importmap)
          app.config.importmap.paths << root.join('config/importmap.rb')
          # https://github.com/rails/importmap-rails?tab=readme-ov-file#sweeping-the-cache-in-development-and-test
          app.config.importmap.cache_sweepers << root.join('app/javascript')
        end
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
