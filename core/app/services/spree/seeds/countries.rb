require 'carmen'

module Spree
  module Seeds
    class Countries
      prepend Spree::ServiceModule::Base

      EXCLUDED_COUNTRIES = ['AQ', 'AX', 'GS', 'UM', 'HM', 'IO', 'EH', 'BV', 'TF'].freeze

      def call
        ApplicationRecord.transaction do
          if Rails::VERSION::MAJOR >= 6
            new_countries = Carmen::Country.all.map do |country|
              # Skip the creation of some territories, uninhabited islands and the Antarctic.
              next if EXCLUDED_COUNTRIES.include?(country.alpha_2_code)

              Hash[
                'name': country.name,
                'iso3': country.alpha_3_code,
                'iso': country.alpha_2_code,
                'iso_name': country.name.upcase,
                'numcode': country.numeric_code,
              ]
            end.compact.uniq
            Spree::Country.insert_all(new_countries)
          else
            Carmen::Country.all.each do |country|
              # Skip the creation of some territories, uninhabited islands and the Antarctic.
              next if EXCLUDED_COUNTRIES.include?(country.alpha_2_code)

              Spree::Country.where(
                name: country.name,
                iso3: country.alpha_3_code,
                iso: country.alpha_2_code,
                iso_name: country.name.upcase,
                numcode: country.numeric_code
              ).first_or_create!
            end
          end

          # Find countries that do not use postal codes (by iso) and set 'zipcode_required' to false for them.
          Spree::Country.where(iso: Spree::Address::NO_ZIPCODE_ISO_CODES).update_all(zipcode_required: false)

          # Find all countries that require a state (province) at checkout and set 'states_required' to true.
          Spree::Country.where(iso: Spree::Address::STATES_REQUIRED).update_all(states_required: true)
        end
      end
    end
  end
end
