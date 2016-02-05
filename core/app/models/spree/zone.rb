module Spree
  class Zone < Spree::Base
    with_options dependent: :destroy, inverse_of: :zone do
      has_many :zone_members, class_name: "Spree::ZoneMember"
      has_many :tax_rates
    end
    with_options through: :zone_members, source: :zoneable do
      has_many :countries, source_type: "Spree::Country"
      has_many :states, source_type: "Spree::State"
    end

    has_many :shipping_method_zones, class_name: 'Spree::ShippingMethodZone'
    has_many :zones, through: :shipping_method_zones, class_name: 'Spree::Zone'

    validates :name, presence: true, uniqueness: { allow_blank: true }

    after_save :remove_defunct_members
    after_save :remove_previous_default

    alias :members :zone_members
    accepts_nested_attributes_for :zone_members, allow_destroy: true, reject_if: proc { |a| a['zoneable_id'].blank? }

    self.whitelisted_ransackable_attributes = ['description']

    def self.default_tax
      find_by(default_tax: true)
    end

    def self.potential_matching_zones(zone)
      if zone.country?
        # Match zones of the same kind with similar countries
        joins(countries: :zones).
          where("zone_members_spree_countries_join.zone_id = ?", zone.id).
          uniq
      else
        # Match zones of the same kind with similar states in AND match zones
        # that have the states countries in
        joins(:zone_members).where(
          "(spree_zone_members.zoneable_type = 'Spree::State' AND
            spree_zone_members.zoneable_id IN (?))
           OR (spree_zone_members.zoneable_type = 'Spree::Country' AND
            spree_zone_members.zoneable_id IN (?))",
          zone.state_ids,
          zone.states.pluck(:country_id)
        ).uniq
      end
    end

    # Returns the matching zone with the highest priority zone type (State, Country, Zone.)
    # Returns nil in the case of no matches.
    def self.match(address)
      return unless address &&
                    matches = includes(:zone_members).
                              order('spree_zones.zone_members_count', 'spree_zones.created_at').
                              where("(spree_zone_members.zoneable_type = 'Spree::Country' AND " +
                                      "spree_zone_members.zoneable_id = ?) OR " +
                                      "(spree_zone_members.zoneable_type = 'Spree::State' AND " +
                                      "spree_zone_members.zoneable_id = ?)", address.country_id, address.state_id).
                              references(:zones)

      ['state', 'country'].each do |zone_kind|
        if match = matches.detect { |zone| zone_kind == zone.kind }
          return match
        end
      end
      matches.first
    end

    def kind
      if kind?
        super
      else
        not_nil_scope = members.where.not(zoneable_type: nil)
        zone_type = not_nil_scope.order('created_at ASC').pluck(:zoneable_type).last
        zone_type.demodulize.underscore if zone_type
      end
    end

    def country?
      kind == 'country'
    end

    def state?
      kind == 'state'
    end

    def include?(address)
      return false unless address

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

    # convenience method for returning the countries contained within a zone
    def country_list
      @countries ||= case kind
                     when 'country' then
                       zoneables
                     when 'state' then
                       zoneables.collect(&:country)
                     else
                       []
                     end.flatten.compact.uniq
    end

    def <=>(other)
      name <=> other.name
    end

    # All zoneables belonging to the zone members.  Will be a collection of either
    # countries or states depending on the zone type.
    def zoneables
      members.includes(:zoneable).collect(&:zoneable)
    end

    def country_ids
      if kind == 'country'
        members.pluck(:zoneable_id)
      else
        []
      end
    end

    def state_ids
      if kind == 'state'
        members.pluck(:zoneable_id)
      else
        []
      end
    end

    def country_ids=(ids)
      set_zone_members(ids, 'Spree::Country')
    end

    def state_ids=(ids)
      set_zone_members(ids, 'Spree::State')
    end

    # Indicates whether the specified zone falls entirely within the zone performing
    # the check.
    def contains?(target)
      return false if state? && target.country?
      return false if zone_members.empty? || target.zone_members.empty?

      if kind == target.kind
        if state?
          return false if (target.states.pluck(:id) - states.pluck(:id)).present?
        elsif country?
          return false if (target.countries.pluck(:id) - countries.pluck(:id)).present?
        end
      else
        return false if (target.states.pluck(:country_id) - countries.pluck(:id)).present?
      end
      true
    end

    private

    def remove_defunct_members
      if zone_members.any?
        zone_members.where('zoneable_id IS NULL OR zoneable_type != ?', "Spree::#{kind.classify}").destroy_all
      end
    end

    def remove_previous_default
      Spree::Zone.where('id != ?', id).update_all(default_tax: false) if default_tax
    end

    def set_zone_members(ids, type)
      zone_members.destroy_all
      ids.reject(&:blank?).map do |id|
        member = ZoneMember.new
        member.zoneable_type = type
        member.zoneable_id = id
        members << member
      end
    end
  end
end
