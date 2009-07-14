require 'test/helper'

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
      @file = File.new(File.join(File.dirname(__FILE__), "fixtures", "5k.png"), 'rb')
    end

    teardown { @file.close }

    context "that is sent #stream_to" do

      context "and given a String" do
        setup do
          FileUtils.mkdir_p(File.join(ROOT, 'tmp'))
          assert @result = @file.stream_to(File.join(ROOT, 'tmp', 'iostream.string.test'))
        end

        should "return a File" do
          assert @result.is_a?(File)
        end

        should "contain the same data as the original file" do
          @file.rewind; @result.rewind
          assert_equal @file.read, @result.read
        end
      end

      context "and given a Tempfile" do
        setup do
          tempfile = Tempfile.new('iostream.test')
          tempfile.binmode
          assert @result = @file.stream_to(tempfile)
        end

        should "return a Tempfile" do
          assert @result.is_a?(Tempfile)
        end

        should "contain the same data as the original file" do
          @file.rewind; @result.rewind
          assert_equal @file.read, @result.read
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
