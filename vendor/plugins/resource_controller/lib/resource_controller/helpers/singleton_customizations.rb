# Singleton Resource Helpers
# 
# Used internally to transform a plural RESTful controller into a singleton
#
module ResourceController
  module Helpers
    module SingletonCustomizations
      def self.included(subclass)
        subclass.class_eval do  
          methods_to_undefine = [:param, :index, :collection, :load_collection, :collection_url, 
            :collection_path, :hash_for_collection_url, :hash_for_collection_path]
          methods_to_undefine.each { |method| undef_method(method) if method_defined? method }
      
          class << self
            def singleton?
              true
            end
          end
        end
      end
  
      protected
        # Used to fetch the current object in a singleton controller.
        #
        # By defult this method is able to fetch the current object for resources nested with the :has_one association only. (i.e. /users/1/image # => @user.image)
        # In other cases you should override this method and provide your custom code to fetch a singleton resource object, like using a session hash.
        #
        # class AccountsController < ResourceController::Singleton
        #   private
        #     def object
        #       @object ||= Account.find(session[:account_id])
        #     end
        #   end
        #  
        def object
          @object ||= parent? ? end_of_association_chain : nil
        end

        # Returns the :has_one association proxy of the parent. (i.e. /users/1/image # => @user.image)
        #  
        def parent_association
          @parent_association ||= parent_object.send(model_name.to_sym)
        end
  
        # Used internally to provide the options to smart_url in a singleton controller.
        #  
        def object_url_options(action_prefix = nil, alternate_object = nil)
          [action_prefix] + namespaces + [parent_url_options, route_name.to_sym]
        end
  
        # Builds the object, but doesn't save it, during the new, and create action.
        #
        def build_object
          @object ||= singleton_build_object_base.send parent? ? "build_#{model_name}".to_sym : :new, object_params
        end
    
        # Singleton controllers don't build off of association proxy, so we can't use end_of_association_chain here
        #
        def singleton_build_object_base
          parent? ? parent_object : model
        end
    end
  end
end
