module Spree
  module  DatabaseTypeUtilities
    def self.maximum_value_for(data_type)
      case data_type
      when :integer
        ActiveModel::Type::Integer.new.instance_eval { range.max }
      else
        raise ArgumentError.new('Currently only :integer argument is acceptable')
      end
    end
  end
end
