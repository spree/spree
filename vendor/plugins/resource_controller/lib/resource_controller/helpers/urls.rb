# Thanks to Urligence, you get some free url helpers.
# 
# No matter what your controller looks like...
# 
#   [edit_|new_]object_url # is the equivalent of saying [edit_|new_]post_url(@post)
#   [edit_|new_]object_url(some_other_object) # allows you to specify an object, but still maintain any paths or namespaces that are present
# 
#   collection_url # is like saying posts_url
# 
# Url helpers are especially useful when working with polymorphic controllers.
# 
#   # /posts/1/comments
#   object_url #=> /posts/1/comments/#{@comment.to_param}
#   object_url(comment) #=> /posts/1/comments/#{comment.to_param}
#   edit_object_url #=> /posts/1/comments/#{@comment.to_param}/edit
#   collection_url #=> /posts/1/comments
# 
#   # /products/1/comments
#   object_url #=> /products/1/comments/#{@comment.to_param}
#   object_url(comment) #=> /products/1/comments/#{comment.to_param}
#   edit_object_url #=> /products/1/comments/#{@comment.to_param}/edit
#   collection_url #=> /products/1/comments
# 
#   # /comments
#   object_url #=> /comments/#{@comment.to_param}
#   object_url(comment) #=> /comments/#{comment.to_param}
#   edit_object_url #=> /comments/#{@comment.to_param}/edit
#   collection_url #=> /comments
# 
# Or with namespaced, nested controllers...
# 
#   # /admin/products/1/options
#   object_url #=> /admin/products/1/options/#{@option.to_param}
#   object_url(option) #=> /admin/products/1/options/#{option.to_param}
#   edit_object_url #=> /admin/products/1/options/#{@option.to_param}/edit
#   collection_url #=> /admin/products/1/options
# 
# You get the idea.  Everything is automagical!  All parameters are inferred.
#
module ResourceController
  module Helpers
    module Urls
      protected
        ['', 'edit_'].each do |type|
          symbol = type.blank? ? nil : type.gsub(/_/, '').to_sym
      
          define_method("#{type}object_url") do |*alternate_object|
            smart_url *object_url_options(symbol, alternate_object.first)
          end
      
          define_method("#{type}object_path") do |*alternate_object|
            smart_path *object_url_options(symbol, alternate_object.first)
          end
      
          define_method("hash_for_#{type}object_url") do |*alternate_object|
            hash_for_smart_url *object_url_options(symbol, alternate_object.first)
          end
      
          define_method("hash_for_#{type}object_path") do |*alternate_object|
            hash_for_smart_path *object_url_options(symbol, alternate_object.first)
          end
        end
    
        def new_object_url
          smart_url *new_object_url_options
        end
    
        def new_object_path
          smart_path *new_object_url_options
        end
    
        def hash_for_new_object_url
          hash_for_smart_url *new_object_url_options
        end
    
        def hash_for_new_object_path
          hash_for_smart_path *new_object_url_options
        end
    
        def collection_url
          smart_url *collection_url_options
        end
    
        def collection_path
          smart_path *collection_url_options
        end
    
        def hash_for_collection_url
          hash_for_smart_url *collection_url_options
        end
    
        def hash_for_collection_path
          hash_for_smart_path *collection_url_options
        end
    
        # Used internally to provide the options to smart_url from Urligence.
        #
        def collection_url_options
          namespaces + [parent_url_options, route_name.to_s.pluralize.to_sym]
        end
    
        # Used internally to provide the options to smart_url from Urligence.
        #
        def object_url_options(action_prefix = nil, alternate_object = nil)
          [action_prefix] + namespaces + [parent_url_options, [route_name.to_sym, alternate_object || object]]
        end
    
        # Used internally to provide the options to smart_url from Urligence.
        #
        def new_object_url_options
          [:new] + namespaces + [parent_url_options, route_name.to_sym]
        end
    
        def parent_url_options
          if parent?
            parent_singleton? ? parent_type.to_sym : [parent_type.to_sym, parent_object]
          else
            nil
          end
        end
    
        # Returns all of the current namespaces of the current controller, symbolized, in array form.
        #
        def namespaces
          names = self.class.name.split("::")
          names.pop
      
          names.map(&:underscore).map(&:to_sym)
        end
    end
  end
end
