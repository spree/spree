module ActionController
  class Base
    class << self
      def set_view_path(path)
        [:append_view_path, :view_paths=, :template_root=].each do |method|
          if respond_to?(method)
            return send(method, path)
          end
        end
      end
    end
  end
end
        
