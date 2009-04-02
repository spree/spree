module Compass
  module Frameworks
    ALL = []
    class Framework
      attr_accessor :name
      attr_accessor :templates_directory, :stylesheets_directory
      def initialize(name, *arguments)
        options = arguments.last.is_a?(Hash) ? arguments.pop : {}
        path = options[:path] || arguments.shift
        @name = name
        @templates_directory = options[:templates_directory] || File.join(path, 'templates')
        @stylesheets_directory = options[:stylesheets_directory] || File.join(path, 'stylesheets')
      end
    end
    def register(name, *arguments)
      ALL << Framework.new(name, *arguments)
    end
    def [](name)
      ALL.detect{|f| f.name.to_s == name.to_s}
    end
    module_function :register, :[]
  end
end

# Import all of the default frameworks.
default_frameworks_directory = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'frameworks'))
Dir.glob(File.join(default_frameworks_directory, "*.rb")).each do |framework|
  require framework
end
