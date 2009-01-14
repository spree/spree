
class SingleStiParent < ActiveRecord::Base
  has_many_polymorphs :the_bones, :from => [:bones], :through => :single_sti_parent_relationship
end
