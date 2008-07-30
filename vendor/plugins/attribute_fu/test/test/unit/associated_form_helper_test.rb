require File.dirname(__FILE__)+'/../test_helper'

class AssociatedFormHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::FormHelper
  include ActionView::Helpers::FormTagHelper
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TextHelper
  include AttributeFu::AssociatedFormHelper
    
  def setup
    @photo   = Photo.create
    @controller = mock()
    @controller.stubs(:url_for).returns 'asdf'
    @controller.stubs(:protect_against_forgery?).returns false
    stubs(:protect_against_forgery?).returns false
  end
    
  context "fields for associated" do
    context "with existing object" do
      setup do
        @photo.comments.create :author => "Barry", :body => "Oooh I did good today..."

        @erbout = assoc_output @photo.comments.first
      end

      should "name field with attribute_fu naming conventions" do
        assert_match "photo[comment_attributes][#{@photo.comments.first.id}]", @erbout
      end
    end

    context "with non-existent object" do
      setup do      
        @erbout = assoc_output(@photo.comments.build) do |f|
          f.fields_for_associated(@photo.comments.build) do |comment|
            comment.text_field(:author)
          end
        end
      end

      should "name field with attribute_fu naming conventions" do
        assert_match "photo[comment_attributes][new][0]", @erbout
      end

      should "maintain the numbering of the new object if called again" do
        assert_match "photo[comment_attributes][new][1]", @erbout
      end
    end
    
    context "with overridden name" do
      setup do
        _erbout = ''
        fields_for(:photo) do |f|
          f.fields_for_associated(@photo.comments.build, :name => :something_else) do |comment|
            _erbout.concat comment.text_field(:author)
          end
        end
        
        @erbout = _erbout
      end

      should "use override name" do
        assert_dom_equal "<input name='photo[something_else_attributes][new][0][author]' size='30' type='text' id='photo_something_else_attributes__new__0_author' />", @erbout
      end
    end
  end
  
  context "remove link" do
    context "with just a name" do
      setup do
        remove_link "remove"
      end

      should "create a link" do
        assert_match ">remove</a>", @erbout
      end

      should "infer the name of the current @object in fields_for" do
        assert_match "$(this).up('.comment').remove()", @erbout
      end
    end
    
    context "with an alternate CSS selector" do
      setup do
        remove_link "remove", :selector => '.blah'
      end

      should "use the alternate selector" do
        assert_match "$(this).up('.blah').remove()", @erbout
      end
    end
    
    context "with an extra function" do
      setup do
        @other_function = "$('asdf').blah();"
        remove_link "remove", :function => @other_function
      end

      should "still infer the name of the current @object in fields_for, and create the function as usual" do
        assert_match "$(this).up('.comment').remove()", @erbout
      end
      
      should "append the secondary function" do
        assert_match @other_function, @erbout
      end
    end
  end
  
  context "with javascript flag" do
    setup do
      _erbout = ''
      fields_for(:photo) do |f|
        _erbout.concat(f.fields_for_associated(@photo.comments.build, :javascript => true) do |comment|
          comment.text_field(:author)
        end)
      end
      
      @erbout = _erbout
    end
    
    should "use placeholders instead of numbers" do
      assert_match 'photo[comment_attributes][new][#{number}]', @erbout
    end
  end
  
  context "add_associated_link " do
    setup do
      comment = @photo.comments.build
      
      _erbout = ''
      fields_for(:photo) do |f|
        f.stubs(:render_associated_form).with(comment, :fields_for => {:javascript => true}, :partial => 'comment')
        _erbout.concat f.add_associated_link("Add Comment", comment, :class => 'something')
      end
      
      @erbout = _erbout
    end

    should "create link" do
      assert_match ">Add Comment</a>", @erbout
    end
    
    should "insert into the bottom of the parent container by default" do
      assert_match "Insertion.Bottom('comments'", @erbout
    end
    
    should "wrap the partial in a prototype template" do
      assert_match "new Template", @erbout
      assert_match "evaluate", @erbout
    end
    
    should "name the variable correctly" do
      assert_match "attribute_fu_comment_count", @erbout
    end
    
    should "pass along the additional options to the link_to_function call" do
      assert_match 'class="something"', @erbout
    end
    
    should "produce the following link" do
      # this is a way of testing the whole link
      assert_equal %{
        <a class=\"something\" href=\"#\" onclick=\"if (typeof attribute_fu_comment_count == 'undefined') attribute_fu_comment_count = 0;\nnew Insertion.Bottom('comments', new Template(null).evaluate({'number': --attribute_fu_comment_count})); return false;\">Add Comment</a>
      }.strip, @erbout
    end
  end
  
  context "add_associated_link with parameters" do
    setup do
      comment = @photo.comments.build
      
      _erbout = ''
      fields_for(:photo) do |f|
        f.stubs(:render_associated_form).with(comment, :fields_for => {:javascript => true}, :partial => 'some_other_partial')
        _erbout.concat f.add_associated_link("Add Comment", comment, :container => 'something_comments', :partial => 'some_other_partial')
      end
      
      @erbout = _erbout
    end

    should "create link" do
      assert_match ">Add Comment</a>", @erbout
    end
    
    should "insert into the bottom of the container specified" do
      assert_match "Insertion.Bottom('something_comments'", @erbout
    end
    
    should "wrap the partial in a prototype template" do
      assert_match "new Template", @erbout
      assert_match "evaluate", @erbout
    end
    
    should "name the variable correctly" do
      assert_match "attribute_fu_comment_count", @erbout
    end
    
    should "produce the following link" do
      # this is a way of testing the whole link
      assert_equal %{
        <a href=\"#\" onclick=\"if (typeof attribute_fu_comment_count == 'undefined') attribute_fu_comment_count = 0;\nnew Insertion.Bottom('something_comments', new Template(null).evaluate({'number': --attribute_fu_comment_count})); return false;\">Add Comment</a>
      }.strip, @erbout
    end
  end
  
  context "add associated link with expression parameter" do
    setup do
      comment = @photo.comments.build
      
      _erbout = ''
      fields_for(:photo) do |f|
        f.stubs(:render_associated_form).with(comment, :fields_for => {:javascript => true}, :partial => 'some_other_partial')
        _erbout.concat f.add_associated_link("Add Comment", comment, :expression => '$(this).up(".something_comments")', :partial => 'some_other_partial')
      end
      
      @erbout = _erbout
    end

    should "create link" do
      assert_match ">Add Comment</a>", @erbout
    end
    
    should "use the javascript expression provided instead of passing the ID in" do
      assert_match "Insertion.Bottom($(this).up(&quot;.something_comments&quot;)", @erbout
    end
    
    should "wrap the partial in a prototype template" do
      assert_match "new Template", @erbout
      assert_match "evaluate", @erbout
    end
    
    should "name the variable correctly" do
      assert_match "attribute_fu_comment_count", @erbout
    end
    
    should "produce the following link" do
      # this is a way of testing the whole link
      assert_equal %{
        <a href=\"#\" onclick=\"if (typeof attribute_fu_comment_count == 'undefined') attribute_fu_comment_count = 0;\nnew Insertion.Bottom($(this).up(&quot;.something_comments&quot;), new Template(null).evaluate({'number': --attribute_fu_comment_count})); return false;\">Add Comment</a>
      }.strip, @erbout
    end    
  end
  
  context "render_associated_form" do
    setup do
      comment = @photo.comments.build
      
      associated_form_builder = mock()
      
      _erbout = ''
      fields_for(:photo) do |f|
        f.stubs(:fields_for_associated).yields(associated_form_builder)
        expects(:render).with(:partial => "comment", :locals => { :comment => comment, :f => associated_form_builder })
        _erbout.concat f.render_associated_form(comment).to_s
      end
      
      @erbout = _erbout
    end
    
    should "extract the correct parameters for render" do
      # assertions in mock
    end
  end
  
  context "render_associated_form with specified partial name" do
    setup do
      comment = @photo.comments.build
      
      associated_form_builder = mock()
      
      _erbout = ''
      fields_for(:photo) do |f|
        f.stubs(:fields_for_associated).yields(associated_form_builder)
        expects(:render).with(:partial => "somewhere/something.html.erb", :locals => { :something => comment, :f => associated_form_builder })
        _erbout.concat f.render_associated_form(comment, :partial => "somewhere/something.html.erb").to_s
      end
      
      @erbout = _erbout
    end
    
    should "extract the correct parameters for render" do
      # assertions in mock
    end
  end
  
  context "render_associated_form with collection" do
    setup do
      associated_form_builder = mock()
      new_comment = Comment.new
      @photo.comments.expects(:build).returns(new_comment).times(3)
      @photo.comments.stubs(:empty?).returns(false)
      @photo.comments.stubs(:first).returns(new_comment)
      @photo.comments.stubs(:map).yields(new_comment)
      
      _erbout = ''
      fields_for(:photo) do |f|
        f.stubs(:fields_for_associated).yields(associated_form_builder)
        expects(:render).with(:partial => "comment", :locals => { :comment => new_comment, :f => associated_form_builder })
        _erbout.concat f.render_associated_form(@photo.comments, :new => 3).to_s
      end
      
      @erbout = _erbout
    end
    
    should "extract the correct parameters for render" do
      # assertions in mock
    end
  end
  
  context "render_associated_form with collection that already has a couple of new objects in it" do
    setup do
      associated_form_builder = mock()
      2.times { @photo.comments.build }
      new_comment = Comment.new
      @photo.comments.expects(:build).returns(new_comment)
      @photo.comments.stubs(:empty?).returns(false)
      @photo.comments.stubs(:first).returns(new_comment)
      @photo.comments.stubs(:map).yields(new_comment)
      
      _erbout = ''
      fields_for(:photo) do |f|
        f.stubs(:fields_for_associated).yields(associated_form_builder)
        expects(:render).with(:partial => "comment", :locals => { :comment => new_comment, :f => associated_form_builder })
        _erbout.concat f.render_associated_form(@photo.comments, :new => 3).to_s
      end
      
      @erbout = _erbout
    end
    
    should "extract the correct parameters for render" do
      # assertions in mock
    end
  end
  
  context "render_associated_form with overridden name" do
    setup do
      associated_form_builder = mock()
      comment = @photo.comments.build
      
      _erbout = ''
      fields_for(:photo) do |f|
        f.stubs(:fields_for_associated).with(comment, :name => 'something_else').yields(associated_form_builder)
        expects(:render).with(:partial => "something_else", :locals => { :something_else => comment, :f => associated_form_builder })
        _erbout.concat f.render_associated_form(@photo.comments, :name => :something_else).to_s
      end
      
      @erbout = _erbout
    end
    
    should "render with correct parameters" do
      # assertions in mock
    end
  end
  
  private
    def assoc_output(comment, &block)
      _erbout = ''
      fields_for(:photo) do |f|
        _erbout.concat(f.fields_for_associated(comment) do |comment|
          comment.text_field(:author)
        end)
        
        _erbout.concat yield(f) if block_given?
      end
      
      _erbout
    end
    
    def remove_link(*args)
      @erbout = assoc_output(@photo.comments.build) do |f|
        f.fields_for_associated(@photo.comments.build) do |comment|
          comment.remove_link *args
        end
      end
    end
end
