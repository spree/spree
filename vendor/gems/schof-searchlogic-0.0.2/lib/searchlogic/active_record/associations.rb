module Searchlogic
  module ActiveRecord
    # = Searchlogic ActiveRecord Associations
    #
    # These methods hook into ActiveRecords association methods and add in searchlogic functionality.
    module Associations
      module AssociationCollection
        # This needs to be implemented because AR doesn't leverage scopes with this method like it probably should
        def find_with_searchlogic(*args)
          options = args.extract_options!
          args << filter_options_with_searchlogic(options)
          find_without_searchlogic(*args)
        end
      end
      
      module HasManyAssociation
        def count_with_searchlogic(*args)
          options = args.extract_options!
          args << filter_options_with_searchlogic(options)
          count_without_searchlogic(*args)
        end
      end
    end
  end
end

ActiveRecord::Associations::AssociationCollection.class_eval do
  if respond_to?(:find)
    include Searchlogic::ActiveRecord::Associations::AssociationCollection
    alias_method_chain :find, :searchlogic
  end
end

ActiveRecord::Associations::HasManyAssociation.class_eval do
  include Searchlogic::ActiveRecord::Associations::HasManyAssociation
  alias_method_chain :count, :searchlogic
  
  # Older versions of AR have find in here, not in AssociationCollection
  include Searchlogic::ActiveRecord::Associations::AssociationCollection
  alias_method_chain :find, :searchlogic
end

ActiveRecord::Associations::ClassMethods::InnerJoinDependency::InnerJoinAssociation.class_eval do
  private
    # Inner joins impose limitations on queries. They can be quicker but you can't do OR conditions when conditions
    # overlap from the base model to any of its associations. Also, inner joins won't allow you to order by an association
    # attribute. What if the association is optional? All of those records are ommitted. It just doesn't make sense to default
    # to inner joins when providing this as a "convenience" when searching. So let's change it.
    def join_type
      "LEFT OUTER JOIN"
    end
end