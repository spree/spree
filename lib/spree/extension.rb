require 'annotatable'
require 'simpleton'
#require 'radiant/admin_ui'

module Spree
  class Extension
    include Simpleton
    include Annotatable

    annotate :version, :description, :url, :root, :extension_name

    attr_writer :active

    def active?
      @active
    end
    
    def migrator
      ExtensionMigrator.new(self)
    end
=begin
    def admin
      AdminUI.instance
    end
=end
    def meta
      self.class.meta
    end

    class << self

      def activate_extension
        return if instance.active?
        instance.activate if instance.respond_to? :activate
        #ActionController::Routing::Routes.reload
        add_hooks_listener
        instance.active = true
      end
      alias :activate :activate_extension

      def define_routes(&block)
        route_definitions << block
      end
      
      def add_hooks_listener
        hooks_name = "#{name.underscore.gsub(/_extension$/, '')}_hooks"
        if File.exists?(File.join(root, "#{hooks_name}.rb"))
          hooks_class = hooks_name.camelize.constantize
          hooks_class.unloadable
          Spree::ThemeSupport::Hook.add_listener(hooks_class)
        end
      end

      def inherited(subclass)
        subclass.extension_name = subclass.name.to_name('Extension')
      end

      def meta
        Spree::ExtensionMeta.find_or_create_by_name(extension_name)
      end
      
      def route_definitions        
        @route_definitions ||= []
      end

    end
  end
end