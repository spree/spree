module Spree
  module DataFeeds
    module Google
      class OptionalAttributes
        prepend Spree::ServiceModule::Base

        def call(input)
          information = {}

          input[:product].property_ids.each do |key|
            name = Spree::Property.find(key)&.name
            value = input[:product].property(name)
            unless value.nil?
              information[name] = value
            end
          end

          success(information: information)
        end
      end
    end
  end
end
