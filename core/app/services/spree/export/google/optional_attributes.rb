module Spree
  module Export
    module Google
      class OptionalAttributes
        prepend Spree::ServiceModule::Base

        def call(input)
          information = {}

          input[:settings].enabled_keys.each do |key|
            if input[:settings].send(key) && !input[:product].property(key.to_s).nil?
              information[key] = input[:product].property(key.to_s)
            end
          end

          success(information: information)
        end
      end
    end
  end
end
