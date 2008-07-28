module ResourceController # :nodoc:
  module Accessors # :nodoc:
    private
      def block_accessor(*accessors)
        accessors.each do |block_accessor|
          class_eval <<-"end_eval", __FILE__, __LINE__

            def #{block_accessor}(*args, &block)
              unless args.empty? && block.nil?
                args.push block if block_given?
                @#{block_accessor} = [args].flatten
              end
              
              @#{block_accessor}
            end

          end_eval
        end
      end
      
      def scoping_reader(*accessor_names)
        accessor_names.each do |accessor_name|        
          class_eval <<-"end_eval", __FILE__, __LINE__
            def #{accessor_name}(&block)
              @#{accessor_name}.instance_eval &block if block_given?
              @#{accessor_name}
            end
          end_eval
        end
      end
      
      def class_scoping_reader(accessor_name, start_value)
        write_inheritable_attribute accessor_name, start_value
        
        class_eval <<-"end_eval", __FILE__, __LINE__
          def self.#{accessor_name}(&block)
            read_inheritable_attribute(:#{accessor_name}).instance_eval(&block) if block_given?
            read_inheritable_attribute(:#{accessor_name})
          end
        end_eval
      end
      
      def reader_writer(accessor_name)
        class_eval <<-"end_eval", __FILE__, __LINE__
          def #{accessor_name}(*args, &block)
            args << block unless block.nil?
            @#{accessor_name} = args.first unless args.empty?
            @#{accessor_name}
          end
        end_eval
      end
      
      def class_reader_writer(*accessor_names)
        accessor_names.each do |accessor_name|
          class_eval <<-"end_eval", __FILE__, __LINE__
            def self.#{accessor_name}(*args)
              unless args.empty?
                write_inheritable_attribute :#{accessor_name}, args.first if args.length == 1
                write_inheritable_attribute :#{accessor_name}, args if args.length > 1
              end
            
              read_inheritable_attribute :#{accessor_name}
            end
          
            def #{accessor_name}(*args)
              unless args.empty?
                self.class.write_inheritable_attribute :#{accessor_name}, args.first if args.length == 1
                self.class.write_inheritable_attribute :#{accessor_name}, args if args.length > 1
              end
            
              self.class.read_inheritable_attribute :#{accessor_name}
            end
          end_eval
        end
      end
  end
end