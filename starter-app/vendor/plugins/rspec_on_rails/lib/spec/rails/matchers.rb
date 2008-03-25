dir = File.dirname(__FILE__)
require 'spec/rails/matchers/assert_select'
require 'spec/rails/matchers/have_text'
require 'spec/rails/matchers/redirect_to'
require 'spec/rails/matchers/render_template'

module Spec
  module Rails
    # Spec::Rails::Expectations::Matchers provides several expectation matchers
    # intended to work with Rails components like models and responses. For example:
    #
    #   response.should redirect_to("some/url") #redirect_to(url) is the matcher.
    #
    # In addition to those you see below, the arbitrary predicate feature of RSpec
    # makes the following available as well:
    #
    #   response.should be_success #passes if response.success?
    #   response.should be_redirect #passes if response.redirect?
    #
    # Note that many of these matchers are part of a wrapper of <tt>assert_select</tt>, so
    # the documentation comes straight from that with some slight modifications.
    # <tt>assert_select</tt> is a Test::Unit extension originally contributed to the
    # Rails community as a plugin by Assaf Arkin and eventually shipped as part of Rails.
    #
    # For more info on <tt>assert_select</tt>, see the relevant Rails documentation.
    module Matchers
    end
  end
end
