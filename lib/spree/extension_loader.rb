#######################################################################################################
# Substantial portions of this code were adapted from the Radiant CMS project (http://radiantcms.org) #
#######################################################################################################
require 'spree/extension'
require 'method_observer'

module Spree
  class ExtensionLoader
    
    class DependenciesObserver < MethodObserver
      attr_accessor :config
      
      def initialize(rails_config)
        @config = rails_config
      end
      
      def after_clear(*args)
        ExtensionLoader.load_extensions
        ExtensionLoader.activate_extensions
      end
    end

    include Simpleton
    
    attr_accessor :initializer, :extensions
    
    def initialize
      self.extensions = []
    end
    
    def configuration
      initializer.configuration
    end
    
    def extension_load_paths
      load_extension_roots.map { |extension| load_paths_for(extension) }.flatten
    end

    def plugin_paths
      load_extension_roots.map {|extension| "#{extension}/vendor/plugins" }.select {|d| File.directory?(d) }
    end

    def db_paths dir
      load_extension_roots.map {|extension| File.join(extension, "db", dir ) }.select {|d| File.directory?(d) }
    end
        
    def add_extension_paths
      extension_load_paths.reverse_each do |path|
        configuration.load_paths.unshift path
        $LOAD_PATH.unshift path
      end
    end
    
    def add_plugin_paths
      configuration.plugin_paths.concat plugin_paths
    end

    def controller_paths
      extensions.map { |extension| "#{extension.root}/app/controllers" }.select { |d| File.directory?(d) }
    end
    
    def add_controller_paths
      configuration.controller_paths.concat(controller_paths)
    end
    
    def locale_paths
      load_extension_roots.map { |extension|  Dir[File.join("#{extension}/config/locales" , '*.{rb,yml}')]  }.flatten
    end
    
    def add_locale_paths
      configuration.i18n.load_path.concat(locale_paths)
    end
 
    def view_paths
      extensions.map { |extension| "#{extension.root}/app/views" }.select { |d| File.directory?(d) }
    end
    
    def stylesheet_source_paths
      extensions.map { |extension| "#{extension.root}/app/stylesheets" }.select { |d| File.directory?(d) }
    end

    # Load the extensions
    def load_extensions
      @observer ||= DependenciesObserver.new(configuration).observe(ActiveSupport::Dependencies)
      self.extensions = load_extension_roots.map do |root|
        begin
          extension_file = "#{File.basename(root).sub(/^\d+_/,'')}_extension"       
          extension = extension_file.camelize.constantize
          extension.unloadable
          extension.root = root
          extension
        rescue LoadError, NameError => e
          $stderr.puts "Could not load extension from file: #{extension_file}.\n#{e.inspect}"
          nil
        end
      end.compact
    end
    
    def activate_extensions
      # Reset the view paths after 
      initializer.initialize_framework_views
      extensions.each &:activate
    end
    alias :reactivate :activate_extensions

    def run_initializers
      load_extension_roots.each do |extension_path|
        Dir["#{extension_path}/config/initializers/**/*.rb"].sort.each do |initializer|
          Rails.logger.info "INFO: Loading initializer #{initializer}"
          load(initializer)
        end
      end
    end 

    def load_extension_roots
      @load_extension_roots ||= unless configuration.extensions.empty?
        select_extension_roots
      else
        []
      end
    end

    private

      def load_paths_for(dir)
        if File.directory?(dir)
          %w(lib app/models app/controllers app/helpers app/metal test/helpers).collect do |p|
            path = "#{dir}/#{p}"
            path if File.directory?(path)
          end.compact << dir
        else
          []
        end
      end
      
      def select_extension_roots
        all_roots = all_extension_roots.dup
        
        roots = configuration.extensions.map do |ext_name|
          if :all === ext_name
            :all
          else
            ext_path = all_roots.detect do |maybe_path|
              File.basename(maybe_path).sub(/^\d+_/, '') == ext_name.to_s
            end
            raise LoadError, "Cannot find the extension '#{ext_name}'!" if ext_path.nil?
            all_roots.delete(ext_path)
          end
        end

        if placeholder = roots.index(:all)
          # replace the :all symbol with any remaining paths
          roots[placeholder, 1] = all_roots
        end
        roots
      end
      
      def all_extension_roots
        @all_extension_roots ||= configuration.extension_paths.map do |path|
          Dir["#{path}/*"].map {|f| File.expand_path(f) if File.directory?(f) }.compact.sort
        end.flatten
      end
  end
end
