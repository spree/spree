require 'rubygems'
require 'test/unit'
require 'stringio'
require 'tempfile'
require 'shoulda'

require File.join(File.dirname(__FILE__), '..', 'lib', 'paperclip', 'iostream.rb')

class IOStreamTest < Test::Unit::TestCase
  context "IOStream" do
    should "be included in IO, File, Tempfile, and StringIO" do
      [IO, File, Tempfile, StringIO].each do |klass|
        assert klass.included_modules.include?(IOStream), "Not in #{klass}"
      end
    end
  end

  context "A file" do
    setup do
      @file = File.new(File.join(File.dirname(__FILE__), "fixtures", "5k.png"))
    end

    context "that is sent #stream_to" do

      [["/tmp/iostream.string.test", File],
       [Tempfile.new('iostream.test'), Tempfile]].each do |args|

        context "and given a #{args[0].class.to_s}" do
          setup do
            assert @result = @file.stream_to(args[0])
          end

          should "return a #{args[1].to_s}" do
            assert @result.is_a?(args[1])
          end

          should "contain the same data as the original file" do
            @file.rewind; @result.rewind
            assert_equal @file.read, @result.read
          end
        end
      end
    end

    context "that is sent #to_tempfile" do
      setup do
        assert @tempfile = @file.to_tempfile
      end

      should "convert it to a Tempfile" do
        assert @tempfile.is_a?(Tempfile)
      end

      should "have the Tempfile contain the same data as the file" do
        @file.rewind; @tempfile.rewind
        assert_equal @file.read, @tempfile.read
      end
    end
  end
end
