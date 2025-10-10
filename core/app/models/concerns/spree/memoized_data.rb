module Spree
  module MemoizedData
    extend ActiveSupport::Concern

    included do
      # reset cache on save inside transaction and transaction commit
      after_save :reset_memoized_data
      after_commit :reset_memoized_data

      def reload(options = {})
        reset_memoized_data
        super(options)
      end

      private

      def reset_memoized_data
        self.class.const_get('MEMOIZED_METHODS').each do |v|
          instance_variable_set(:"@#{v.gsub(/\?/, '')}", nil)
        end
      end
    end
  end
end
