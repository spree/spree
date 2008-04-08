# Here we add a single helpful method to ActiveRecord::Base. This method may be deprecated
# in the future, since support for the Module#config mechanism which required it has
# also been dropped.
module Engines::RailsExtensions::ActiveRecord
  # NOTE: Currently the Migrations system will ALWAYS wrap given table names
  # in the prefix/suffix, so any table name set via ActiveRecord::Base#set_table_name, 
  # for instance will always get wrapped in the process of migration. For this 
  # reason, whatever value you give to the config will be wrapped when set_table_name 
  # is used in the model.
  #
  # This method is useful for determining the actual name (including prefix and 
  # suffix) that Rails will use for a model, given a particular set_table_name
  # parameter.
  def wrapped_table_name(name)
    table_name_prefix + name + table_name_suffix
  end
  
end

module ::ActiveRecord #:nodoc:
  class Base #:nodoc:
    extend Engines::RailsExtensions::ActiveRecord
  end
end
