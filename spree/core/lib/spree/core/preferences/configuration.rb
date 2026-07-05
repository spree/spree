# This takes the preferable methods and adds some
# syntactic sugar to access the preferences
#
# class App < Configuration
#   preference :color, :string
# end
#
# a = App.new
#
# setters:
# a.color = :blue
# a[:color] = :blue
# a.set :color = :blue
# a.preferred_color = :blue
#
# getters:
# a.color
# a[:color]
# a.get :color
# a.preferred_color
#
#

require_relative 'runtime_configuration'

module Spree::Preferences
  class Configuration < Spree::Preferences::RuntimeConfiguration
  end
end
