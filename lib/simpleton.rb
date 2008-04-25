#######################################################################################################
# Substantial portions of this code were adapted from the Radiant CMS project (http://radiantcms.org) #
#######################################################################################################
module Simpleton
  
  def self.included(base)
    base.extend(ClassMethods)
  end
  
  module ClassMethods
    
    def instance(&block)
      @instance ||= new
      block.call(@instance) if block_given?
      @instance
    end
    
    def method_missing(method, *args, &block)
      instance.respond_to?(method) ? instance.send(method, *args, &block) : super
    end
    
  end
  
end