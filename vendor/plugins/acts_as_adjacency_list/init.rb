require 'active_record/acts/adjacency_list'
# reopen ActiveRecord and include all the above to make
# them available to all our models if they want it
ActiveRecord::Base.class_eval do
  include ActiveRecord::Acts::AdjacencyList
end

# alternatively, you can use this call:
# ActiveRecord::Base.send :include, Foo::Acts::Fox
