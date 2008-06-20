module ResourceController
  # == ResourceController::Helpers
  #
  # Included in Base.
  # 
  # These helpers are used internally to manage objects, generate urls, and manage parent resource associations.
  #
  # If you want to customize certain controller behaviour, like member-object, and collection fetching, overriding these methods is all it takes.
  #
  # See the docs below, and the README for examples
  #
  # *Please Note: many of these helpers build on top of each other, and require that behaviour to be maintained, in order for other functionality to work properly.*
  # 
  # e.g. All fetching must be done on top of the method end_of_association_chain, or else parent resources (including polymorphic ones) won't function correctly.
  #   
  #   class PostsController < ResourceController::Base
  #   private
  #     def object
  #       @object ||= end_of_association_chain.find_by_permalink(param)
  #     end
  #   end
  module Helpers
    include ResourceController::Helpers::Urls
    include ResourceController::Helpers::Internal
    include ResourceController::Helpers::Nested
    include ResourceController::Helpers::CurrentObjects
  end
end
