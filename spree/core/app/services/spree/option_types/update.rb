module Spree
  module OptionTypes
    class Update
      prepend Spree::ServiceModule::Base

      def call(option_type:, params:)
        ApplicationRecord.transaction do
          run :update_option_type
          run :sync_option_values
        end
      end

      private

      def update_option_type(option_type:, params:)
        params = params.to_h.with_indifferent_access
        option_values_params = params.delete(:option_values)
        sync_values = !option_values_params.nil?

        if option_type.update(params)
          success(option_type: option_type, option_values_params: option_values_params, sync_values: sync_values)
        else
          failure(option_type, option_type.errors)
        end
      end

      def sync_option_values(option_type:, option_values_params:, sync_values:)
        return success(option_type: option_type) unless sync_values

        now = Time.current
        names = []

        records = (option_values_params || []).each_with_index.map do |value_data, index|
          value_data = value_data.to_h.with_indifferent_access
          names << value_data[:name]
          {
            option_type_id: option_type.id,
            name: value_data[:name],
            presentation: value_data[:presentation],
            position: value_data[:position] || (index + 1),
            created_at: now,
            updated_at: now
          }
        end

        # Remove option values not in the payload
        option_type.option_values.where.not(name: names).destroy_all

        if records.any?
          Spree::OptionValue.upsert_all(
            records,
            unique_by: :index_spree_option_values_on_option_type_id_and_name,
            update_only: [:presentation, :position]
          )
        end

        success(option_type: option_type.reload)
      end
    end
  end
end
