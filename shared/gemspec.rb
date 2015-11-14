module Spree
  module Gemspec
    AUTHORS = {
      'Sean Schofield' => 'sean@spreecommerce.com',
      'Ryan Bigg'      => 'ryan@spreecommerce.com'
    }.freeze

    # Add shared settings to gemspec
    #
    # @param gem [Gem::Specification]
    #
    # @return [self]
    def self.shared(gem)
      gem.authors               = AUTHORS.keys
      gem.email                 = AUTHORS.values
      gem.files                 = Dir.glob('{LICENSE.md,{app,config,lib,db,vendor}/**/*')
      gem.platform              = Gem::Platform::RUBY
      gem.required_ruby_version = '>= 1.9.3'
      gem.require_path          = 'lib'
      gem.version               = '2.4.11.beta'

      self
    end
  end # Gemspec
end # Spree
