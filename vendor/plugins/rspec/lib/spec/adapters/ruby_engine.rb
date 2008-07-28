require 'spec/adapters/ruby_engine/mri'
require 'spec/adapters/ruby_engine/rubinius'

module Spec
  module Adapters
    module RubyEngine
    
      ENGINES = {
        'mri' => MRI.new,
        'rbx' => Rubinius.new
      }
    
      def self.engine
        if Object.const_defined?('RUBY_ENGINE')
          return Object.const_get('RUBY_ENGINE')
        else
          return 'mri'
        end
      end
    
      def self.adapter
        return ENGINES[engine]
      end
    end
  end
end