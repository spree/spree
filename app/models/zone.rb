class Zone < ActiveRecord::Base
  has_many :zone_members
  validates_presence_of :name
  validates_uniqueness_of :name
  after_save :remove_defunct_members
  
  alias :members :zone_members
  accepts_nested_attributes_for :zone_members, :allow_destroy => true, :reject_if => proc { |a| a['zoneable_id'].blank? }
  
  #attr_accessor :type
  def kind
    return "country" unless member = self.members.last
    return "state" if member.zoneable_type == "State"
    return "zone" if member.zoneable_type == "Zone"
    "country"
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
    # NOTE: This is complicated by the fact that include? for HMP is broken in Rails 2.1 (so we use awkward index method)
    case self.kind
    when "country"
      return members.select { |zone_member| zone_member.zoneable == address.country }.any?
    when "state"
      return members.select { |zone_member| zone_member.zoneable == address.state }.any?
      #members.index(address.state).respond_to?(:integer?)
    end
    members.each do |zone_member|
      return true if zone_member.zoneable.include?(address)
    end
    false
  end
  
  def self.match(address)
    zones = []
    Zone.all.each {|zone| zones << zone if zone.include?(address)}
    zones
  end
  
  # convenience method for returning the countries contained within a zone (different then the countries method which only 
  # returns the zones children and does not consider the grand children if the children themselves are zones)
  def country_list
    return [] if kind == "state"
    return members.collect { |zone_member| zone_member.zoneable } if kind == "country"
    members.collect { |zone_member| zone_member.zoneable.country_list }.flatten
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
