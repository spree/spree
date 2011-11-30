module Spree::Preferences
  class Definition
    attr_accessor :name, :value_type, :default

    def initialize
      yield(self) if block_given?
    end

    def to_s
      "name: #{@name}, value_type: #{@value_type}, default: #{@default}"
    end

  end
end
