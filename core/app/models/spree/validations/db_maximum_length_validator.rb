module Spree
  module Validations
    ##
    # Validates a field based on the maximum length of the underlying DB field, if there is one.
    class DbMaximumLengthValidator < ActiveModel::Validator
      def initialize(options)
        super
        @field = options[:field].to_s
        raise ArgumentError, 'a field must be specified to the validator' if @field.blank?
      end

      def validate(record)
        warn '`Spree::Validations::DbMaximumLengthValidator` is deprecated. Use `DbMaximumLengthValidator` instead.'
        limit = record.class.columns_hash[@field].limit
        value = record[@field.to_sym]
        if value && limit && value.to_s.length > limit
          record.errors.add(@field.to_sym, :too_long, count: limit)
        end
      end
    end
  end
end
