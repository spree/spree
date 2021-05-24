module Spree
  module Account
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
          state_name = params[:state_name]
          return params unless state_name.present?

          country ||= Spree::Country.find(params[:country_id]) if params[:country_id].present?
          return params unless country

          params[:state_id] = country.states.find_by(name: state_name)&.id
          params
        end

        def assign_to_user_as_default(user:, address_id:)
          if user.addresses.pluck(:id) == [address_id] # check if it's user first address
            user.update(bill_address_id: address_id, ship_address_id: address_id)
          end
        end
      end
    end
  end
end
