require File.expand_path(File.join(File.dirname(__FILE__), '../../../../test/test_helper'))
require 'test/unit'

class InPlaceEditingTest < Test::Unit::TestCase
  include InPlaceEditing
  include InPlaceMacrosHelper
  
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::FormHelper
  include ActionView::Helpers::CaptureHelper
  
  def setup
    @controller = Class.new do
      def url_for(options)
        url =  "http://www.example.com/"
        url << options[:action].to_s if options and options[:action]
        url
      end
    end
    @controller = @controller.new
  end
  
  def test_in_place_editor_external_control
      assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nnew Ajax.InPlaceEditor('some_input', 'http://www.example.com/inplace_edit', {externalControl:'blah'})\n//]]>\n</script>),
        in_place_editor('some_input', {:url => {:action => 'inplace_edit'}, :external_control => 'blah'})
  end
  
  def test_in_place_editor_size
      assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nnew Ajax.InPlaceEditor('some_input', 'http://www.example.com/inplace_edit', {size:4})\n//]]>\n</script>),
        in_place_editor('some_input', {:url => {:action => 'inplace_edit'}, :size => 4})
  end
  
  def test_in_place_editor_cols_no_rows
      assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nnew Ajax.InPlaceEditor('some_input', 'http://www.example.com/inplace_edit', {cols:4})\n//]]>\n</script>),
        in_place_editor('some_input', {:url => {:action => 'inplace_edit'}, :cols => 4})
  end
  
  def test_in_place_editor_cols_with_rows
      assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nnew Ajax.InPlaceEditor('some_input', 'http://www.example.com/inplace_edit', {cols:40, rows:5})\n//]]>\n</script>),
        in_place_editor('some_input', {:url => {:action => 'inplace_edit'}, :rows => 5, :cols => 40})
  end

  def test_inplace_editor_loading_text
      assert_dom_equal %(<script type=\"text/javascript\">\n//<![CDATA[\nnew Ajax.InPlaceEditor('some_input', 'http://www.example.com/inplace_edit', {loadingText:'Why are we waiting?'})\n//]]>\n</script>),
        in_place_editor('some_input', {:url => {:action => 'inplace_edit'}, :loading_text => 'Why are we waiting?'})
  end
  
  def test_in_place_editor_url
    assert_match "Ajax.InPlaceEditor('id-goes-here', 'http://www.example.com/action_to_set_value')",
    in_place_editor( 'id-goes-here', :url => { :action => "action_to_set_value" })    
  end
  
  def test_in_place_editor_load_text_url
    assert_match "Ajax.InPlaceEditor('id-goes-here', 'http://www.example.com/action_to_set_value', {loadTextURL:'http://www.example.com/action_to_get_value'})",
    in_place_editor( 'id-goes-here', 
      :url => { :action => "action_to_set_value" }, 
      :load_text_url => { :action => "action_to_get_value" })
  end
  
  def test_in_place_editor_eval_scripts
    assert_match "Ajax.InPlaceEditor('id-goes-here', 'http://www.example.com/action_to_set_value', {evalScripts:true})",
    in_place_editor( 'id-goes-here', 
      :url => { :action => "action_to_set_value" }, 
      :script => true )
  end
  
end