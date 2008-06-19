
$:.unshift(File.dirname(__FILE__) + '/../../../lib')
require 'paginating_find'
require File.dirname(__FILE__) + '/../test_helper'
require File.join(File.dirname(__FILE__), '/../fixtures/models')
load(File.dirname(__FILE__) + "/../../db/schema.rb")
load(File.dirname(__FILE__) + "/../../../init.rb")
