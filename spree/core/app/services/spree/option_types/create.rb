module Spree
  module OptionTypes
    class Create
      prepend Spree::ServiceModule::Base

      def call(params:)
        ApplicationRecord.transaction do
          run :create_option_type
          run :sync_option_values
        end
      end

      private

      def create_option_type(params:)
        params = params.to_h.with_indifferent_access
        option_values_params = params.delete(:option_values)

        option_type = Spree::OptionType.new(params)

        if option_type.save
          success(option_type: option_type, option_values_params: option_values_params)
        else
          failure(option_type, option_type.errors)
        end
      end

      def sync_option_values(option_type:, option_values_params:)
        return success(option_type: option_type) if option_values_params.blank?

        now = Time.current

        records = option_values_params.each_with_index.map do |value_data, index|
          value_data = value_data.to_h.with_indifferent_access
          {
            option_type_id: option_type.id,
            name: value_data[:name],
            presentation: value_data[:presentation],
            position: value_data[:position] || (index + 1),
            created_at: now,
            updated_at: now
          }
        end

        Spree::OptionValue.insert_all!(records)

        success(option_type: option_type.reload)
      end
    end
  end
end
