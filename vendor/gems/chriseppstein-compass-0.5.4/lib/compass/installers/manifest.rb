module Compass
  module Installers

    class Manifest

      # A Manifest entry
      class Entry < Struct.new(:type, :from, :options)
        def to
          options[:to] || from
        end
      end

      def initialize(manifest_file = nil)
        @entries = []
        parse(manifest_file) if manifest_file
      end

      def self.type(t)
        eval <<-END
          def #{t}(from, options = {})
             @entries << Entry.new(:#{t}, from, options)
          end
          def has_#{t}?
            @entries.detect {|e| e.type == :#{t}}
          end
          def each_#{t}
            @entries.select {|e| e.type == :#{t}}.each {|e| yield e}
          end
        END
      end

      type :stylesheet
      type :image
      type :javascript
      type :file

      # Enumerates over the manifest files
      def each
        @entries.each {|e| yield e}
      end


      protected
      # parses a manifest file which is a ruby script
      # evaluated in a Manifest instance context
      def parse(manifest_file)
        open(manifest_file) do |f|
          eval(f.read, instance_binding, manifest_file)
        end
      end
      def instance_binding
        binding
      end
    end

  end
end