module Spree
  module Promo
    class Engine < Rails::Engine
      isolate_namespace Spree
      engine_name 'spree_promo'

      def self.activate
        require 'decorators'
        Decorators.register! root
      end

      def self.root
        @root ||= Pathname.new(File.expand_path('../../../../', __FILE__))
      end

      config.autoload_paths += %W(#{config.root}/lib)
      config.to_prepare &method(:activate).to_proc

      initializer 'spree.promo.environment', :after => 'spree.environment' do |app|
        app.config.spree.add_class('promotions')
        app.config.spree.promotions = Spree::Promo::Environment.new
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
