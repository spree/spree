require 'parentship'
class Person < ActiveRecord::Base                   
  has_many_polymorphs :kids,
                      :through => :parentships, 
                      :from => [:people], 
                      :as => :parent,
                      :polymorphic_type_key => "child_type",
                      :conditions => "people.age < 10"   
end                                               
