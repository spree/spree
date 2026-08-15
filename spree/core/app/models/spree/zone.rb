module Spree
  # Migration-only shell, removed in Spree 6.1: rows survive solely as source
  # data for the 5.6→6.0 zone, market and tax migrations. Countries and states
  # are reference data in 6.0, so member ids resolve against the legacy tables
  # rather than through associations.
  class Zone < Spree.base_class
    has_prefix_id :zone

    include Spree::UniqueName

    has_many :zone_members, class_name: 'Spree::ZoneMember', dependent: :destroy, inverse_of: :zone
    alias members zone_members

    # The stored kind, falling back to what the members point at — legacy rows
    # predating the column carry the type only on their members.
    def kind
      if self[:kind].present?
        self[:kind]
      else
        zone_type = zone_members.where.not(zoneable_type: nil).order(created_at: :asc).pluck(:zoneable_type).last
        zone_type&.demodulize&.underscore
      end
    end

    def country?
      kind == 'country'
    end

    def state?
      kind == 'state'
    end

    # The countries the zone covers, as value objects; a state member resolves
    # through its state's country.
    #
    # @return [Array<Spree::Country>]
    def country_list
      connection = self.class.connection
      members_by_type = zone_members.where.not(zoneable_type: nil).group_by(&:zoneable_type)

      isos = Array(members_by_type['Spree::Country']).filter_map do |member|
        connection.select_value("SELECT iso FROM spree_countries WHERE id = #{connection.quote(member.zoneable_id)}")
      end
      isos += Array(members_by_type['Spree::State']).filter_map do |member|
        connection.select_value(<<~SQL.squish)
          SELECT spree_countries.iso
          FROM spree_states
          INNER JOIN spree_countries ON spree_countries.id = spree_states.country_id
          WHERE spree_states.id = #{connection.quote(member.zoneable_id)}
        SQL
      end

      isos.uniq.filter_map { |iso| Spree::Country.by_iso(iso) }
    end
  end
end
