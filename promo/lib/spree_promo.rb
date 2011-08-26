require 'spree_core'
require 'spree_auth'

module SpreePromo
  class Engine < Rails::Engine
    engine_name 'spree_promo'

    def self.activate
      Dir.glob(File.join(File.dirname(__FILE__), "../app/**/*_decorator*.rb")) do |c|
       Rails.application.config.cache_classes ? require(c) : load(c)
      end
      Dir.glob(File.join(File.dirname(__FILE__), "../app/overrides/*.rb")) do |c|
        Rails.application.config.cache_classes ? require(c) : load(c)
      end

      # Include list of visited paths in notification payload hash
      SpreeBase::InstanceMethods.class_eval do
        def default_notification_payload
          {:user => current_user, :order => current_order, :visited_paths => session[:visited_paths]}
        end
      end

      if Activator.table_exists?
        # register promotion rules and actions
        [Promotion::Rules::ItemTotal,
         Promotion::Rules::Product,
         Promotion::Rules::User,
         Promotion::Rules::FirstOrder,
         Promotion::Rules::LandingPage,
         Promotion::Rules::UserLoggedIn,
         Promotion::Actions::CreateAdjustment,
         Promotion::Actions::CreateLineItems
        ].each &:register

        # register default promotion calculators
        [
          Calculator::FlatPercentItemTotal,
          Calculator::FlatRate,
          Calculator::FlexiRate,
          Calculator::PerItem,
          Calculator::FreeShipping
        ].each{|c_model|
          begin
            Promotion::Actions::CreateAdjustment.register_calculator(c_model) if c_model.table_exists?
          rescue Exception => e
            $stderr.puts "Error registering promotion calculator #{c_model}"
          end
        }
      end

    end

    config.autoload_paths += %W(#{config.root}/lib)
    config.to_prepare &method(:activate).to_proc
  end
end
