module Spree
  module Imports
    module RowProcessors
      class Customer < Base
        def process!
          user = find_or_initialize_user
          assign_user_attributes(user)
          assign_address(user) if address_fields_present?
          user.save!
          user
        end

        private

        def find_or_initialize_user
          email = attributes['email'].to_s.strip.downcase
          raise ArgumentError, 'Email is required' if email.blank?

          Spree.user_class.find_or_initialize_by(email: email)
        end

        def assign_user_attributes(user)
          user.first_name = attributes['first_name'].strip if attributes['first_name'].present?
          user.last_name = attributes['last_name'].strip if attributes['last_name'].present?
          user.phone = attributes['phone'].strip if attributes['phone'].present?
          user.accepts_email_marketing = to_boolean(attributes['accepts_email_marketing']) if attributes['accepts_email_marketing'].present?
          user.tag_list = attributes['tags'] if attributes['tags'].present?

          if user.new_record?
            password = SecureRandom.hex(16)
            user.password = password
            user.password_confirmation = password
          end
        end

        def assign_address(user)
          address = user.bill_address || user.build_bill_address
          address.firstname = attributes['first_name'].presence || user.first_name
          address.lastname = attributes['last_name'].presence || user.last_name
          address.company = attributes['company'].strip if attributes['company'].present?
          address.address1 = attributes['address1'].strip if attributes['address1'].present?
          address.address2 = attributes['address2'].strip if attributes['address2'].present?
          address.city = attributes['city'].strip if attributes['city'].present?
          address.zipcode = attributes['zip'].strip if attributes['zip'].present?
          address.phone = attributes['phone'].presence || user.phone

          if attributes['country_code'].present?
            address.country = Spree::Country.find_by(iso: attributes['country_code'].strip.upcase)
          end

          if attributes['province_code'].present? && address.country
            address.state = address.country.states.find_by(abbr: attributes['province_code'].strip)
          end

          address.save!
          user.bill_address = address
          user.ship_address ||= address
        end

        def address_fields_present?
          %w[address1 city country_code].any? { |f| attributes[f].present? }
        end

        def to_boolean(value)
          value.to_s.strip.downcase.in?(%w[true yes 1 y])
        end
      end
    end
  end
end
