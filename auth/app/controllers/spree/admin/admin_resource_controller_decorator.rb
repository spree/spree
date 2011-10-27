Spree::Admin::ResourceController.class_eval do
   authorize_resource :class => lambda { model_class }
end
