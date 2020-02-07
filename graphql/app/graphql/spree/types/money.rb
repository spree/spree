module Spree
  class Types::Money < ::GraphQL::Schema::Scalar
    description "Spree money type"

    def self.coerce_input(input_value, context)
      money = Spree::Money.new(input_value)
      return money if money

      raise GraphQL::CoercionError, "#{input_value.inspect} is not a valid Money"
    end

    def self.coerce_result(ruby_value, context)
      ruby_value.to_s
    end
  end
end
