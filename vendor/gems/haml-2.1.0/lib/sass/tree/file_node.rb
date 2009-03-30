module Sass
  module Tree
    class FileNode < Node
      def initialize(filename, children, options)
        @filename = filename
        super(options)
        self.children = children
      end

      def to_s(*args)
        super()
      rescue Sass::SyntaxError => e
        e.add_backtrace_entry(@filename)
        raise e
      end

      protected

      def perform!(environment)
        self.children = perform_children(environment)
      rescue Sass::SyntaxError => e
        e.add_backtrace_entry(@filename)
        raise e
      end
    end
  end
end
