#!/usr/bin/env ruby

unless ARGV.length == 2
  puts "Usage: release.rb human_name tag_name"
  exit
end

tag_name   = ARGV[1]
human_name = ARGV.first
repo_root  = "http://svn.jamesgolick.com/resource_controller"

puts "tagging #{human_name}"
`svn copy #{repo_root}/trunk #{repo_root}/tags/#{tag_name} -m"tagging #{human_name}"`
puts "tagging edge_compatible #{human_name}"
`svn copy #{repo_root}/branches/edge_compatible #{repo_root}/tags/edge_compatible/#{tag_name} -m"tagging edge_compatible #{human_name}"`

puts "deleting previous stable tags"
`svn rm #{repo_root}/tags/stable #{repo_root}/tags/edge_compatible/stable -m"deleting previous stable tags"`

puts "tag stable release"
`svn copy #{repo_root}/tags/#{tag_name} #{repo_root}/tags/stable -m"tag stable release"`
puts "tag stable edge_compatible release"

`svn copy #{repo_root}/tags/edge_compatible/#{tag_name} #{repo_root}/tags/edge_compatible/stable -m"tag stable edge_compatible release"`