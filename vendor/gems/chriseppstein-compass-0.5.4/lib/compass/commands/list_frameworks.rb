module Compass
  module Commands
    class ListFrameworks
      attr_accessor :options
      def initialize(working_path, options)
        self.options = options
      end
  
      def perform
        Compass::Frameworks::ALL.each do |framework|
          puts framework.name
        end
      end
    end
  end
end