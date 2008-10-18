module Paperclip
  module Shoulda
    def should_have_attached_file name, options = {}
      klass = self.name.gsub(/Test$/, '').constantize
      context "Class #{klass.name} with attachment #{name}" do
        should "respond to all the right methods" do
          ["#{name}", "#{name}=", "#{name}?"].each do |meth|
            assert klass.instance_methods.include?(meth), "#{klass.name} does not respond to #{name}."
          end
        end

        should "have the correct definition" do
          expected = options
          actual   = klass.attachment_definitions[name]
          expected.delete(:validations)      if not options.key?(:validations)
          expected.delete(:whiny_thumbnails) if not options.key?(:whiny_thumbnails)

          assert_equal expected, actual
        end

        should "ensure that ImageMagick is available" do
          %w( convert identify ).each do |command|
            `#{Paperclip.path_for_command(command)}`
            assert_equal 0, $?, "ImageMagick's #{command} returned with an error. Make sure that #{command} is available at #{Paperclip.path_for_command(command)}"
          end
        end
      end
    end
  end
end

Test::Unit::TestCase.extend(Paperclip::Shoulda)
