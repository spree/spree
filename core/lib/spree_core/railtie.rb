module SpreeCore
  class Engine < Rails::Engine

    config.autoload_paths += %W(#{config.root}/lib)
    # TODO - register state monitor observer?


    # TODO: Is there a better way to make sure something within 'self.activate' only runs once in development?
    def self.activate

      Spree::ThemeSupport::HookListener.subclasses.each do |hook_class|
        Spree::ThemeSupport::Hook.add_listener(hook_class)
      end

      #register all payment methods (unless we're in middle of rake task since migrations cannot be run for this first time without this check)
      if File.basename( $0 ) != "rake"
        [
          Gateway::Bogus,
          Gateway::AuthorizeNet,
          Gateway::AuthorizeNetCim,
          Gateway::Eway,
          Gateway::Linkpoint,
          Gateway::PayPal,
          Gateway::SagePay,
          Gateway::Beanstream,
          Gateway::Braintree,
          PaymentMethod::Check
        ].each{|gw|
          begin
            gw.register
          rescue Exception => e
            $stderr.puts "Error registering gateway #{gw}: #{e}"
          end
        }

        #register all calculators
        [
          Calculator::FlatPercentItemTotal,
          Calculator::FlatRate,
          Calculator::FlexiRate,
          Calculator::PerItem,
          Calculator::SalesTax,
          Calculator::Vat,
          Calculator::PriceBucket
        ].each{|c_model|
          begin
            c_model.register if c_model.table_exists?
          rescue Exception => e
            $stderr.puts "Error registering calculator #{c_model}"
          end
        }

      end

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

  end
end
