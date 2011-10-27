module SpreePromo
  class Engine < Rails::Engine
    engine_name 'spree_promo'

    def self.activate
      Dir.glob(File.join(File.dirname(__FILE__), '../../app/**/*_decorator*.rb')) do |c|
        Rails.configuration.cache_classes ? require(c) : load(c)
      end

      # Include list of visited paths in notification payload hash
      SpreeBase::InstanceMethods.class_eval do
        def default_notification_payload
          { :user => current_user, :order => current_order, :visited_paths => session[:visited_paths] }
        end
      end
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
        Spree::Calculator::FreeShipping
      ]
    end

    initializer 'spree.promo.register.promotions.rules' do |app|
      app.config.spree.promotions.rules = [Promotion::Rules::ItemTotal,
         Promotion::Rules::Product,
         Promotion::Rules::User,
         Promotion::Rules::FirstOrder,
         Promotion::Rules::LandingPage,
         Promotion::Rules::UserLoggedIn]
    end

    initializer 'spree.promo.register.promotions.actions' do |app|
      app.config.spree.promotions.actions = [Promotion::Actions::CreateAdjustment,
        Promotion::Actions::CreateLineItems]
    end
  end
end
