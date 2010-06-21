class Zone < ActiveRecord::Base
  has_many :zone_members
  has_many :tax_rates
  has_many :shipping_methods

  validates :name, :presence => true, :uniqueness => true
  after_save :remove_defunct_members

  alias :members :zone_members
  accepts_nested_attributes_for :zone_members, :allow_destroy => true, :reject_if => proc { |a| a['zoneable_id'].blank? }

  # WARNING during tets class method .global is declared to indicate global Zone to use with tests

  #attr_accessor :type
  def kind
    member = self.members.last
    case member && member.zoneable_type
    when "State"  then "state"
    when "Zone"   then "zone"
    else
      "country"
    end
  end

  def kind=(value)
    # do nothing - just here to satisfy the form
  end

  # alias to the new include? method
  def in_zone?(address)
    $stderr.puts "Warning: calling deprecated method :in_zone? use :include? instead."
    include?(address)
  end

  def include?(address)
    return false unless address

    # NOTE: This is complicated by the fact that include? for HMP is broken in Rails 2.1 (so we use awkward index method)
    members.any? do |zone_member|
      case zone_member.zoneable_type
      when "Zone"
        zone_member.zoneable.include?(address)
      when "Country"
        zone_member.zoneable == address.country
      when "State"
        zone_member.zoneable == address.state
      else
        false
      end
    end
  end

  def self.match(address)
    Zone.all.select {|zone| zone.include?(address)}
  end

  # convenience method for returning the countries contained within a zone (different then the countries method which only
  # returns the zones children and does not consider the grand children if the children themselves are zones)
  def country_list
    members.map {|zone_member|
      case zone_member.zoneable_type
      when "Zone"
        zone_member.zoneable.country_list
      when "Country"
        zone_member.zoneable
      when "State"
        zone_member.zoneable.country
      else
        nil
      end
    }.flatten.compact.uniq
  end

  def <=>(other)
    name <=> other.name
  end

  private
  def remove_defunct_members
    zone_members.each do |zone_member|
      zone_member.destroy if zone_member.zoneable_id.nil?
    end
  end
end
