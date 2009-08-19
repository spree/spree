require 'rubygems'
require 'active_support'
require 'action_controller'
require 'rexml/document'
require 'action_controller/vendor/html-scanner'

module TagMatcher
   
   class IncludeTag
      def initialize(*expected)
         @expected = expected.size > 1 ? expected.last.merge({ :tag => expected.first.to_s }) : expected.first
      end
      
      def matches?(target)
         @target = HTML::Document.new(target)
         !@target.find(@expected).nil?
      end
      
      def failure_message
         "expected tag, but no tag found matching #{@expected.inspect} in #{@target.root.to_s}"
      end
      
      def negative_failure_message
         "expected no tag, but tag was found matching #{@expected.inspect} in #{@target.root.to_s}"
      end
   end
   
   def include_tag(*opts)
      IncludeTag.new(*opts)
   end
   
end

module SelectorMatcher
  class SelectorTag
     def initialize(*expected)
       # Then get mandatory selector.
       arg = expected.shift
       
       # string and we pass all remaining arguments.
       # Array and we pass the argument. Also accepts selector itself.
       case arg
         when String
           selector = HTML::Selector.new(arg, expected)
         when Array
           selector = HTML::Selector.new(*arg)
         when HTML::Selector
           selector = arg
         else raise ArgumentError, "Expecting a selector as the first argument"
       end
       
       # Next argument is used for equality tests.
       equals = {}
       case arg = expected.shift
         when Hash
           equals = arg
         when String, Regexp
           equals[:text] = arg
         when Integer
           equals[:count] = arg
         when Range
           equals[:minimum] = arg.begin
           equals[:maximum] = arg.end
         when FalseClass
           equals[:count] = 0
         when NilClass, TrueClass
           equals[:minimum] = 1
         else raise ArgumentError, "I don't understand what you're trying to match"
       end

       # By default we're looking for at least one match.
       if equals[:count]
         equals[:minimum] = equals[:maximum] = equals[:count]
       else
         equals[:minimum] = 1 unless equals[:minimum]
       end
       
       @expected = {:selector => selector, :equals => equals}
     end
     
     def matches?(target)
       @target = HTML::Document.new(target, false, false).root
       
       matches = @expected[:selector].select(@target)
       
       # If text/html, narrow down to those elements that match it.
       content_mismatch = nil
       if match_with = @expected[:equals][:text]
         matches.delete_if do |match|
           text = ""
           text.force_encoding(match_with.encoding) if text.respond_to?(:force_encoding)
           stack = match.children.reverse
           while node = stack.pop
             if node.tag?
               stack.concat node.children.reverse
             else
               content = node.content
               content.force_encoding(match_with.encoding) if content.respond_to?(:force_encoding)
               text << content
             end
           end
           text.strip! unless NO_STRIP.include?(match.name)
           unless match_with.is_a?(Regexp) ? (text =~ match_with) : (text == match_with.to_s)
             true
           end
         end
       elsif match_with = @expected[:equals][:html]
         matches.delete_if do |match|
           html = match.children.map(&:to_s).join
           html.strip! unless NO_STRIP.include?(match.name)
           unless match_with.is_a?(Regexp) ? (html =~ match_with) : (html == match_with.to_s)
             true
           end
         end
       end
       
       # Test minimum/maximum occurrence.
       min, max = @expected[:equals][:minimum], @expected[:equals][:maximum]
       if min && !max
         return matches.size >= min
       elsif max && !min
         return matches.size <= max
       elsif min && max
         return (matches.size >= min) && (matches.size <= max)
       else
         return true
       end
     end
     
     def failure_message
        "expected tag, but no tag found matching #{@expected.inspect} in #{@target.to_s}"
     end
     
     def negative_failure_message
        "expected no tag, but tag was found matching #{@expected.inspect} in #{@target.to_s}"
     end
   end
   
   def selector_tag(*opts)
     SelectorTag.new(*opts)
   end
end
