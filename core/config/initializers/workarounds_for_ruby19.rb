# encoding: utf-8
if RUBY_VERSION.to_f >= 1.9

  class String
    def mb_chars
      self.force_encoding(Encoding::UTF_8)
    end
    
    alias_method(:orig_concat, :concat)
    def concat(value)
      orig_concat value.force_encoding(Encoding::UTF_8)
    end
  end

  module ActionView
    module Renderable #:nodoc:
      private
        def compile!(render_symbol, local_assigns)
          locals_code = local_assigns.keys.map { |key| "#{key} = local_assigns[:#{key}];" }.join

          source = <<-end_src
            def #{render_symbol}(local_assigns)
              old_output_buffer = output_buffer;#{locals_code};#{compiled_source}
            ensure
              self.output_buffer = old_output_buffer
            end
          end_src
          source.force_encoding(Encoding::UTF_8) if source.respond_to?(:force_encoding)

          begin
            ActionView::Base::CompiledTemplates.module_eval(source, filename, 0)
          rescue Errno::ENOENT => e
            raise e # Missing template file, re-raise for Base to rescue
          rescue Exception => e # errors from template code
            if logger = defined?(ActionController) && Base.logger
              logger.debug "ERROR: compiling #{render_symbol} RAISED #{e}"
              logger.debug "Function body: #{source}"
              logger.debug "Backtrace: #{e.backtrace.join("\n")}"
            end

            raise ActionView::TemplateError.new(self, {}, e)
          end
        end
    end
  end

  if defined?(Mysql::Result)
    class Mysql::Result
      def encode(value, encoding = "utf-8")
        String === value ? value.force_encoding(encoding) : value
      end
      
      def each_utf8(&block)
        each_orig do |row|
          yield row.map {|col| encode(col) }
        end
      end
      alias each_orig each
      alias each each_utf8
     
      def each_hash_utf8(&block)
        each_hash_orig do |row|
          row.each {|k, v| row[k] = encode(v) }
          yield(row)
        end
      end
      alias each_hash_orig each_hash
      alias each_hash each_hash_utf8
    end
  end
  
end
