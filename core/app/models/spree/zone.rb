module Spree
  class Zone < Spree::Base
    has_many :zone_members, dependent: :destroy, class_name: "Spree::ZoneMember"
    has_many :tax_rates, dependent: :destroy
    has_and_belongs_to_many :shipping_methods, :join_table => 'spree_shipping_methods_zones'

    validates :name, presence: true, uniqueness: true
    after_save :remove_defunct_members
    after_save :remove_previous_default

    alias :members :zone_members
    accepts_nested_attributes_for :zone_members, allow_destroy: true, reject_if: proc { |a| a['country_code'].blank? }

    def self.default_tax
      where(default_tax: true).first
    end

    # Returns the matching zone with the highest priority zone type (State, Country, Zone.)
    # Returns nil in the case of no matches.
    def self.match(address)
      return unless matches = self.includes(:zone_members).
        order('zone_members_count', 'created_at').
        select { |zone| zone.include? address }

      ['region', 'country'].each do |zone_kind|
        if match = matches.detect { |zone| zone_kind == zone.kind }
          return match
        end
      end
      matches.first
    end

    def kind
      if members.any? && !members.any? { |member| member.kind.nil? }
        members.last.kind
      end
    end

    def kind=(value)
      # do nothing - just here to satisfy the form
    end

    def include?(address)
      return false unless address

      members.any? do |zone_member|
        zone_member.country_code == address.country_code && (zone_member.region_code.nil? || zone_member.region_code == address.region_code)
      end
    end

    # convenience method for returning the countries contained within a zone
    def country_list
      @countries ||= members.collect(&:country).compact.uniq
    end

    def <=>(other)
      name <=> other.name
    end

    def country_codes
      if kind == 'country'
        members.collect(&:country_code)
      else
        []
      end
    end

    def region_codes
      if kind == 'region'
        members.collect(&:region_code)
      else
        []
      end
    end

    def country_codes=(codes)
      zone_members.destroy_all
      codes.reject{ |code| code.blank? }.map do |code|
        member = ZoneMember.new
        member.country_code = code
        members << member
      end
    end

    def region_codes=(codes)
      zone_members.destroy_all
      codes.reject{ |code| code.blank? }.map do |code|
        member = ZoneMember.new
        member.country_code, member.region_code = code.split('-')
        members << member
      end
    end

    # Indicates whether the specified zone falls entirely within the zone performing
    # the check.
    def contains?(target)
      return false if kind == 'region' && target.kind == 'country'
      return false if zone_members.empty? || target.zone_members.empty?
      return false if target.zone_members.any? { |target_member| !zone_members.any? { |member| member.contains?(target_member) } }

      true
    end

    private

      def remove_defunct_members
        if zone_members.any?
          if kind == 'country'
            zone_members.where('country_code is null or region_code is not null').destroy_all
          else
            zone_members.where('country_code is null or region_code is null').destroy_all
          end
        end
      end

      def remove_previous_default
        Spree::Zone.where('id != ?', self.id).update_all(default_tax: false) if default_tax
      end
  end
end
