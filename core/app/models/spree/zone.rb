module Spree
  class Zone < ActiveRecord::Base
    has_many :zone_members, :dependent => :destroy
    has_many :tax_rates, :dependent => :destroy
    has_many :shipping_methods, :dependent => :nullify

    validates :name, :presence => true, :uniqueness => true
    after_save :remove_defunct_members
    after_save :remove_previous_default

    alias :members :zone_members
    accepts_nested_attributes_for :zone_members, :allow_destroy => true, :reject_if => proc { |a| a['zoneable_id'].blank? }

    attr_accessible :name, :description, :default_tax, :kind

    def kind
      member = self.members.last

      case member && member.zoneable_type
      when 'Spree::State' then 'state'
      else
        'country'
      end
    end

    def kind=(value)
      # do nothing - just here to satisfy the form
    end

    def include?(address)
      return false unless address

      # NOTE: This is complicated by the fact that include? for HMP is broken in Rails 2.1 (so we use awkward index method)
      members.any? do |zone_member|
        case zone_member.zoneable_type
        when 'Spree::Country'
          zone_member.zoneable_id == address.country_id
        when 'Spree::State'
          zone_member.zoneable_id == address.state_id
        else
          false
        end
      end
    end

    # Returns the matching zone with the highest priority zone type (State, Country, Zone.)
    # Returns nil in the case of no matches.
    def self.match(address)
      return unless matches = self.order("created_at").select { |zone| zone.include? address }

      ['state', 'country'].each do |zone_kind|
        if match = matches.detect { |zone| zone_kind == zone.kind }
          return match
        end
      end
      matches.first
    end

    # convenience method for returning the countries contained within a zone
    def country_list
      members.map { |zone_member|
        case zone_member.zoneable_type
        when 'Spree::Country'
          zone_member.zoneable
        when 'Spree::State'
          zone_member.zoneable.country
        else
          nil
        end
      }.flatten.compact.uniq
    end

    def <=>(other)
      name <=> other.name
    end

    # All zoneables belonging to the zone members.  Will be a colelction of either
    # countries or states depending on the zone type.
    def zoneables
      members.collect { |m| m.zoneable }
    end

    def self.default_tax
      Zone.where(:default_tax => true).first
    end

    # Indicates whether the specified zone falls entirely within the zone performing
    # the check.
    def contains?(target)
      return false if self.kind == "state" && target.kind == "country"
      return false if self.zone_members.empty? || target.zone_members.empty?

      if self.kind == target.kind
        target.zoneables.each do |target_zoneable|
          return false unless self.zoneables.include?(target_zoneable)
        end
      else
        target.zoneables.each do |target_state|
          return false unless self.zoneables.include?(target_state.country)
        end
      end
      true
    end

    private
      def remove_defunct_members
        zone_members.each do |zone_member|
          zone_member.destroy if zone_member.zoneable_id.nil? || zone_member.zoneable_type != "Spree::#{self.kind.capitalize}"
        end
      end

      def remove_previous_default
        return unless self.default_tax

        Zone.all.each do |zone|
          zone.update_attribute "default_tax", false unless zone == self
        end
      end
  end
end
