require 'fileutils'

module Spec
  class Translator
    def translate(from, to)
      from = File.expand_path(from)
      to = File.expand_path(to)
      if File.directory?(from)
        translate_dir(from, to)
      elsif(from =~ /\.rb$/)
        translate_file(from, to)
      end
    end
    
    def translate_dir(from, to)
      FileUtils.mkdir_p(to) unless File.directory?(to)
      Dir["#{from}/*"].each do |sub_from|
        path = sub_from[from.length+1..-1]
        sub_to = File.join(to, path)
        translate(sub_from, sub_to)
      end
    end

    def translate_file(from, to)
      translation = ""
      File.open(from) do |io|
        io.each_line do |line|
          translation << translate_line(line)
        end
      end
      File.open(to, "w") do |io|
        io.write(translation)
      end
    end

    def translate_line(line)
      # Translate deprecated mock constraints
      line.gsub!(/:any_args/, 'any_args')
      line.gsub!(/:anything/, 'anything')
      line.gsub!(/:boolean/, 'boolean')
      line.gsub!(/:no_args/, 'no_args')
      line.gsub!(/:numeric/, 'an_instance_of(Numeric)')
      line.gsub!(/:string/, 'an_instance_of(String)')

      return line if line =~ /(should_not|should)_receive/
      
      line.gsub!(/(^\s*)context([\s*|\(]['|"|A-Z])/, '\1describe\2')
      line.gsub!(/(^\s*)specify([\s*|\(]['|"|A-Z])/, '\1it\2')
      line.gsub!(/(^\s*)context_setup(\s*[do|\{])/, '\1before(:all)\2')
      line.gsub!(/(^\s*)context_teardown(\s*[do|\{])/, '\1after(:all)\2')
      line.gsub!(/(^\s*)setup(\s*[do|\{])/, '\1before(:each)\2')
      line.gsub!(/(^\s*)teardown(\s*[do|\{])/, '\1after(:each)\2')
      
      if line =~ /(.*\.)(should_not|should)(?:_be)(?!_)(.*)/m
        pre = $1
        should = $2
        post = $3
        be_or_equal = post =~ /(<|>)/ ? "be" : "equal"
        
        return "#{pre}#{should} #{be_or_equal}#{post}"
      end
      
      if line =~ /(.*\.)(should_not|should)_(?!not)\s*(.*)/m
        pre = $1
        should = $2
        post = $3
        
        post.gsub!(/^raise/, 'raise_error')
        post.gsub!(/^throw/, 'throw_symbol')
        
        unless standard_matcher?(post)
          post = "be_#{post}"
        end
        
        # Add parenthesis
        post.gsub!(/^(\w+)\s+([\w|\.|\,|\(.*\)|\'|\"|\:|@| ]+)(\})/, '\1(\2)\3') # inside a block
        post.gsub!(/^(redirect_to)\s+(.*)/, '\1(\2)') # redirect_to, which often has http:
        post.gsub!(/^(\w+)\s+([\w|\.|\,|\(.*\)|\{.*\}|\'|\"|\:|@| ]+)/, '\1(\2)')
        post.gsub!(/(\s+\))/, ')')
        post.gsub!(/\)\}/, ') }')
        post.gsub!(/^(\w+)\s+(\/.*\/)/, '\1(\2)') #regexps
        line = "#{pre}#{should} #{post}"
      end

      line
    end
    
    def standard_matcher?(matcher)
      patterns = [
        /^be/, 
        /^be_close/,
        /^eql/, 
        /^equal/, 
        /^has/, 
        /^have/, 
        /^change/, 
        /^include/,
        /^match/, 
        /^raise_error/, 
        /^respond_to/, 
        /^redirect_to/, 
        /^satisfy/, 
        /^throw_symbol/,
        # Extra ones that we use in spec_helper
        /^pass/,
        /^fail/,
        /^fail_with/,
      ]
      matched = patterns.detect{ |p| matcher =~ p }
      !matched.nil?
    end
    
  end
end
