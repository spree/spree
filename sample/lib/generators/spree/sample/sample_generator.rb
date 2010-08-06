module Spree
  module Generators
    class SampleGenerator < Rails::Generators::Base

      desc "Copies sample fixtures and images into your Spree application."

      def self.source_root
        @source_root ||= File.expand_path(File.join(File.dirname(__FILE__), 'templates'))
      end

      def copy_stuff
        directory 'db'
      end

    end
  end
end