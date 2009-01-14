# -*- ruby -*-

require 'rubygems'
require 'hoe'

$: << File.dirname(__FILE__) + "/lib/"
require "activesupport"
require './lib/calendar_date_select.rb'

Hoe.new('calendar_date_select', CalendarDateSelect::VERSION) do |p|
  p.rubyforge_name = 'calendar_date_select'
  p.developer('Tim Harper', 'tim c harper at gmail dot com')
end


task :set_version do
  ["lib/calendar_date_select/calendar_date_select.rb", "public/javascripts/calendar_date_select/calendar_date_select.js"].each do |file|
    abs_file = File.dirname(__FILE__) + "/" + file
    src = File.read(abs_file);
    src = src.map do |line|
      case line
      when /^ *VERSION/                        then "  VERSION = '#{ENV['VERSION']}'\n"
      when /^\/\/ CalendarDateSelect version / then "// CalendarDateSelect version #{ENV['VERSION']} - a prototype based date picker\n"
      else
        line
      end
    end.join
    File.open(abs_file, "wb") { |f| f << src }
  end
end
# vim: syntax=Ruby
