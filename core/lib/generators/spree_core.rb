module Spree
  module Generators
    module TemplatePath
      def source_root
        @_spree_source_root ||= File.expand_path(File.join(File.dirname(__FILE__), 'spree', generator_name, 'templates'))
      end
    end
  end
end