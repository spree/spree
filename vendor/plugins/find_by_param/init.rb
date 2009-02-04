require 'find_by_param'
class ActiveRecord::Base
  class_inheritable_accessor :permalink_options
  self.permalink_options = {:param => :id}
  
  #default finders these are overwritten if you use make_permalink in your model
  def self.find_by_param(value,args={})
    find_by_id(value,args)
  end
  def self.find_by_param!(value,args={})
    find(value,args)
  end
  
end
ActiveRecord::Base.send(:include, Railslove::Plugins::FindByParam)


