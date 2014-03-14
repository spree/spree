require 'carmen'

module Spree
  class ZoneMember < Spree::Base
    belongs_to :zone, class_name: 'Spree::Zone', counter_cache: true

    def country
      country = Carmen::Country.coded(country_code)
    end

    def region
      country.subregions.coded(region_code) unless region_code.blank?
    end

    def kind
      type = (region || country).try(:class)

      type.to_s.demodulize.underscore unless type.nil?
    end

    def contains?(target)
      if region.present?
        return false if target.region.nil?
        return false unless region == target.region
      end

      return false unless country == target.country

      true
    end

    def name
      (region || country).try(:name)
    end
  end
end
