class Zone < ActiveRecord::Base
  has_many_polymorphs :members, :from => [:states, :countries, :zones], :through => :zone_members, :as => :parent
  validates_uniqueness_of :name
  
  #attr_accessor :type
  def type
    return "country" unless member = self.members.last
    return "state" if member.class == State
    return "zone" if member.class == Zone
    "country"
  end
  
  # virtual attributes for use with AJAX completion stuff
  def member_name
    # does nothing - just here to satisfy text_field_with_auto_complete (which requires a model property)
  end
    
  def in_zone?(address)
    # NOTE: This is complicated by the fact that include? for HMP is broken in Rails 2.1 (so we use awkward index method)
    case self.type
    when "country"
      return members.index(address.country).respond_to?(:integer?)
    when "state"
      return members.index(address.state).respond_to?(:integer?)
    end
    members.each do |zone|
      return true if zone.in_zone?(address)
    end
    false
  end
end