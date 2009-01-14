
=begin rdoc

Debugging tools for Has_many_polymorphs. 

Enable the different tools by setting the environment variable HMP_DEBUG. Settings with special meaning are <tt>"ruby-debug"</tt>, <tt>"trace"</tt>, and <tt>"dependencies"</tt>.

== Code generation

Enabled by default when HMP_DEBUG is set.

Ouputs a folder <tt>generated_models/</tt> in RAILS_ROOT containing valid Ruby files explaining all the ActiveRecord relationships set up by the plugin, as well as listing the line in the plugin that called each particular association method.

== Ruby-debug

Enable by setting HMP_DEBUG to <tt>"ruby-debug"</tt>.

Starts <tt>ruby-debug</tt> for the life of the process.

== Trace

Enable by setting HMP_DEBUG to <tt>"ruby-debug"</tt>.

Outputs an indented trace of relevant method calls as they occur.

== Dependencies

Enable by setting HMP_DEBUG to <tt>"dependencies"</tt>.

Turns on Rails' default dependency logging.

=end

_logger_warn "debug mode enabled"

class << ActiveRecord::Base
  COLLECTION_METHODS = [:belongs_to, :has_many, :has_and_belongs_to_many, :has_one, 
      :has_many_polymorphs, :acts_as_double_polymorphic_join].each do |method_name|
    alias_method "original_#{method_name}".to_sym, method_name
    undef_method method_name
  end      

  unless defined? GENERATED_CODE_DIR
    GENERATED_CODE_DIR = "#{RAILS_ROOT}/generated_models"
  
    begin
      system "rm -rf #{GENERATED_CODE_DIR}" 
      Dir.mkdir GENERATED_CODE_DIR
    rescue Errno::EACCES
      _logger_warn "no permissions for generated code dir: #{GENERATED_CODE_DIR}"
    end

    if File.exist? GENERATED_CODE_DIR
      alias :original_method_missing :method_missing
      def method_missing(method_name, *args, &block)
        if COLLECTION_METHODS.include? method_name.to_sym
          Dir.chdir GENERATED_CODE_DIR do
            filename = "#{demodulate(self.name.underscore)}.rb"
            contents = File.open(filename).read rescue "\nclass #{self.name}\n\nend\n"
            line = caller[1][/\:(\d+)\:/, 1]
            contents[-5..-5] = "\n  #{method_name} #{args[0..-2].inspect[1..-2]},\n     #{args[-1].inspect[1..-2].gsub(" :", "\n     :").gsub("=>", " => ")}\n#{ block ? "     #{block.inspect.sub(/\@.*\//, '@')}\n" : ""}     # called from line #{line}\n\n"
            File.open(filename, "w") do |file| 
              file.puts contents             
            end
          end
          # doesn't actually display block contents
          self.send("original_#{method_name}", *args, &block)
        else
          self.send(:original_method_missing, method_name, *args, &block)
        end
      end
    end      
    
  end
end

case ENV['HMP_DEBUG']

  when "ruby-debug"
    require 'rubygems'
    require 'ruby-debug'
    Debugger.start
    _logger_warn "ruby-debug enabled."

  when "trace"
    _logger_warn "method tracing enabled"  
    $debug_trace_indent = 0
    set_trace_func (proc do |event, file, line, id, binding, classname|
      if id.to_s =~ /instantiate/ #/IRB|Wirble|RubyLex|RubyToken|Logger|ConnectionAdapters|SQLite3|MonitorMixin|Benchmark|Inflector|Inflections/ 
        if event == 'call'
          puts (" " * $debug_trace_indent) + "#{event}ed #{classname}\##{id} from #{file.split('/').last}::#{line}"
          $debug_trace_indent += 1
        elsif event == 'return'
          $debug_trace_indent -= 1 unless $debug_trace_indent == 0
          puts (" " * $debug_trace_indent) + "#{event}ed #{classname}\##{id}"
        end
      end
    end)
    
  when "dependencies"
    _logger_warn "dependency activity being logged"
    (::Dependencies.log_activity = true) rescue nil
end
