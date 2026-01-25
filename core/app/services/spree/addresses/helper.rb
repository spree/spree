module Spree
  module Addresses
    module Helper
      private

      attr_accessor :country

      def fill_country_and_state_ids(params)
        replace_country_iso_with_id(params)
        fill_state_id(params)
      end

      def replace_country_iso_with_id(params)
        iso = params[:country_iso]
        return params unless iso.present?

        country = Spree::Country.by_iso(iso)
        params[:country_id] = country&.id
        params.delete(:country_iso)
        params
      end

      def fill_state_id(params)
        # Always extract state_abbr - it's not a model attribute
        state_abbr = params.delete(:state_abbr)

        country ||= Spree::Country.find(params[:country_id]) if params[:country_id].present?
        return params unless country

        # Support state_abbr (state abbreviation code, e.g., "CA", "NY")
        if state_abbr.present?
          params[:state_id] = country.states.find_by(abbr: state_abbr)&.id
          return params
        end

        # Support state_name for countries where states are not required
        if params[:state_name].present? && !country.states_required?
          # Keep state_name as-is for countries without required states
          return params
        elsif params[:state_name].present?
          # Try to find state by name if states are required
          params[:state_id] = country.states.find_by(name: params[:state_name])&.id
          params.delete(:state_name)
        end

        params
      end

      def assign_to_user_as_default(user:, address_id:, default_billing: true, default_shipping: true)
        attributes_to_update = {
          ship_address_id: (address_id if default_shipping),
          bill_address_id: (address_id if default_billing),
        }.compact_blank

        user.update_columns(**attributes_to_update, updated_at: Time.current) if attributes_to_update.present?
      end
    end
  end
end
