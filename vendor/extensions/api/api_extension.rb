# Uncomment this if you reference any of your controllers in activate
# require_dependency 'application'

class ApiExtension < Spree::Extension
  version "1.0"
  description "Describe your extension here"
  url "http://yourwebsite.com/api"

  # Please use api/config/routes.rb instead for extension routes.

  # def self.require_gems(config)
  #   config.gem "gemname-goes-here", :version => '1.2.3'
  # end
  
  def activate
    User.class_eval do

      def clear_api_key!
        self.update_attribute(:api_key, "")
      end
      
      def generate_api_key!
        self.update_attribute(:api_key, secure_digest(Time.now, (1..10).map{ rand.to_s }))
      end

      private      
      
      def secure_digest(*args)
        Digest::SHA1.hexdigest(args.flatten.join('--'))
      end

    end

    Admin::UsersController.class_eval do
      
      def generate_api_key
        if object.generate_api_key!
          flash[:notice] = t('api.key_generated')
        end
        redirect_to edit_object_path
      end
      def clear_api_key
        if object.clear_api_key!
          flash[:notice] = t('api.key_cleared')
        end
        redirect_to edit_object_path
      end

    end

    Spree::BaseController.class_eval do
      private  
      def current_user
        return @current_user if defined?(@current_user)
        if current_user_session && current_user_session.user
          return @current_user = current_user_session.user
        end
        if token = request.headers['X-SpreeAPIKey']
          @current_user = User.find_by_api_key(token)
        end
      end
    end
    
    LineItem.class_eval do
      def description
        d = variant.product.name.clone
        d << " (#{variant.options_text})" unless variant.option_values.empty?
        d
      end
    end
    
  end
end


