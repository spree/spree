module Searchlogic
  module Shared
    # = Searchlogic Virtual Classes
    #
    # Creates virtual classes for each model, to implementing a type of caching. So that object instantiation for searchlogic searches is cached. This is lazy, meaning
    # it will only cache when it needs. So the first instantion will be much slow than the following ones. This is cached in the RAM, so if the process is restarted the caching is cleared.
    module VirtualClasses
      def self.included(klass)
        klass.extend ClassMethods
      end
      
      module ClassMethods
        # Creates virtual classes for the class passed to it. This is a neccesity for keeping dynamically created method
        # names specific to models. It provides caching and helps a lot with performance.
        def create_virtual_class(model_class)
          class_search_name = "::Searchlogic::Cache::#{model_class.name.gsub("::", "")}" + name.split(/::/)[1]
  
          begin
            eval(class_search_name)
          rescue NameError
            eval <<-end_eval
              class #{class_search_name} < ::#{name}
                def self.klass
                  #{model_class.name}
                end
        
                def klass
                  #{model_class.name}
                end
              end
      
              #{class_search_name}
            end_eval
          end
        end
      end
    end
  end
end