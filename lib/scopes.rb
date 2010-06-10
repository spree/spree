# This module contains all custom scopes created for selecting products.
#
# All usable scopes *should* be included in SCOPES constant, it represents
# all scopes that are selectable from user interface, extensions can extend
# and modify it, but should provide corresponding translations.
#
# Format of constant is following:
#
#   {
#     :namespace/grouping => {
#       :name_of_the_scope => [:list, :of, :arguments]
#     }
#   }
#
#   This values are used in translation file, to describe them in the interface.
#   So for each scope you define here you have to provide following entry in translation file
#   product_scopes:
#     name_of_the_group:
#       name: Translated name of the group
#       description: Longer description of what this scope group does, inluding
#         any possible help user may need
#       scopes:
#         name_of_the_scope:
#           name: Short name of the scope
#           description: What does this scope does exactly
#           arguments:
#             arg1: Description of argument
#             arg2: Description of second Argument
#
module Scopes
  module_function

  def generate_translation(all_scopes)
    result = {"groups" => {}, "scopes" => {}}
    all_scopes.dup.each_pair do |group_name, scopes|
      result["groups"][group_name.to_s] = {
        'name' => group_name.to_s.humanize,
        'description' => "Scopes for selecting products based on #{group_name.to_s}",
      }

      scopes.each_pair do |scope_name, targs|
        hashed_args = {}
        targs.each{|v| hashed_args[v.to_s] = v.to_s.humanize}
        
        result['scopes'][scope_name.to_s] = {
          'name' => scope_name.to_s.humanize,
          'description' => "",
          'args' => hashed_args.dup
        }
      end
    end

    result
  end

  def generate_translations
    require 'ya2yaml'
    {
      'product_scopes' => generate_translation(Scopes::Product::SCOPES)
    }.ya2yaml
  end
end

# Rails 3 TODO
# ActiveRecord::NamedScope::Scope.class_eval do
#   def to_sql
#     construct_finder_sql({})
#   end
# end     