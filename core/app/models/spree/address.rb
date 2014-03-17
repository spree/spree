require 'carmen'

module Spree
  class Address < Spree::Base
    has_many :shipments, inverse_of: :address

    validates :firstname, :lastname, :address1, :city, :country_code, presence: true
    validates :zipcode, presence: true, if: :require_zipcode?
    validates :phone, presence: true, if: :require_phone?

    validate :region_validate

    alias_attribute :first_name, :firstname
    alias_attribute :last_name, :lastname

    def self.build_default
      country_code = Spree::Config[:default_country_code]
      country = Carmen::Country.coded(country_code) || Carmen::Country.coded('US')
      new(country_code: country.code)
    end

    def self.default(user = nil, kind = "bill")
      if user
        user.send(:"#{kind}_address") || build_default
      else
        build_default
      end
    end

    # Can modify an address if it's not been used in an order (but checkouts controller has finer control)
    # def editable?
    #   new_record? || (shipments.empty? && checkouts.empty?)
    # end

    def full_name
      "#{firstname} #{lastname}".strip
    end

    def region_text
      region.try(:code)
    end

    def region_text=(value)
      unless country.nil?
        region = country.subregions.coded(value) || country.subregions.named(value)
        self.region_code = region.try(:code)
      end
    end

    def same_as?(other)
      return false if other.nil?
      attributes.except('id', 'updated_at', 'created_at') == other.attributes.except('id', 'updated_at', 'created_at')
    end

    alias same_as same_as?

    def to_s
      "#{full_name}: #{address1}"
    end

    def clone
      self.class.new(self.attributes.except('id', 'updated_at', 'created_at'))
    end

    def ==(other_address)
      self_attrs = self.attributes
      other_attrs = other_address.respond_to?(:attributes) ? other_address.attributes : {}

      [self_attrs, other_attrs].each { |attrs| attrs.except!('id', 'created_at', 'updated_at', 'order_id') }

      self_attrs == other_attrs
    end

    def empty?
      attributes.except('id', 'created_at', 'updated_at', 'order_id', 'country_id').all? { |_, v| v.nil? }
    end

    # Generates an ActiveMerchant compatible address hash
    def active_merchant_hash
      {
        name: full_name,
        address1: address1,
        address2: address2,
        city: city,
        state: region.try(:code),
        zip: zipcode,
        country: country.try(:code),
        phone: phone
      }
    end

    def country
      Carmen::Country.coded(country_code)
    end

    def region
      country.subregions.coded(region_code) unless country.nil?
    end

    private
      def require_phone?
        true
      end

      def require_zipcode?
        true
      end

      def region_validate
        # Skip state validation without country (also required)
        # or when disabled by preference
        return if country.nil?
        return unless country.subregions.length > 0

        errors.add(:region_code, :invalid) if region.nil?
      end
  end
end
