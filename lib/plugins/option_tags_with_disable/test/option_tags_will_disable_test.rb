require 'test_helper'

class OptionTagsWillDisableTest < ActionView::TestCase
  tests ActionView::Helpers::FormOptionsHelper
  
  Post = Struct.new('Post', :title, :author_name, :body, :private_post)

  def setup
    @posts = [
      Post.new("<Abe> went home", "<Abe>", "To a little house", true),
      Post.new("Babe went home", "Babe", "To a little house", false),
      Post.new("Cabe went home", "Cabe", "To a little house", false)
    ]
  end
  
  test "options for select with disabled value" do
    assert_dom_equal(
      "<option value=\"Denmark\">Denmark</option>\n<option value=\"&lt;USA&gt;\" disabled=\"disabled\">&lt;USA&gt;</option>\n<option value=\"Sweden\">Sweden</option>",
      options_for_select([ "Denmark", "<USA>", "Sweden" ], [],"<USA>")
    )
  end

  test "options for select with multiple disabled" do
    assert_dom_equal(
      "<option value=\"Denmark\">Denmark</option>\n<option value=\"&lt;USA&gt;\" disabled=\"disabled\">&lt;USA&gt;</option>\n<option value=\"Sweden\" disabled=\"disabled\">Sweden</option>",
      options_for_select([ "Denmark", "<USA>", "Sweden" ], [],["<USA>", "Sweden"])
    )
  end

  test "options for select with selection and disabled value" do
    assert_dom_equal(
      "<option value=\"Denmark\" selected=\"selected\">Denmark</option>\n<option value=\"&lt;USA&gt;\" disabled=\"disabled\">&lt;USA&gt;</option>\n<option value=\"Sweden\">Sweden</option>",
      options_for_select([ "Denmark", "<USA>", "Sweden" ], "Denmark","<USA>")
    )
  end
  
  test "collection options with disabled value" do 
    assert_dom_equal(
      "<option value=\"&lt;Abe&gt;\">&lt;Abe&gt; went home</option>\n<option value=\"Babe\" disabled=\"disabled\">Babe went home</option>\n<option value=\"Cabe\">Cabe went home</option>",
      options_from_collection_for_select(@posts, "author_name", "title", nil, "Babe")
    )
  end

  test "collection options with disabled array" do
    assert_dom_equal(
      "<option value=\"&lt;Abe&gt;\">&lt;Abe&gt; went home</option>\n<option value=\"Babe\" disabled=\"disabled\">Babe went home</option>\n<option value=\"Cabe\" disabled=\"disabled\">Cabe went home</option>",
      options_from_collection_for_select(@posts, "author_name", "title", nil, [ "Babe", "Cabe" ])
    )
  end

  test "collection options with preselected and disabled value" do
    assert_dom_equal(
      "<option value=\"&lt;Abe&gt;\">&lt;Abe&gt; went home</option>\n<option value=\"Babe\" disabled=\"disabled\">Babe went home</option>\n<option value=\"Cabe\" selected=\"selected\">Cabe went home</option>",
      options_from_collection_for_select(@posts, "author_name", "title", "Cabe", "Babe")
    )
  end  

  test "collection options with proc for disabled" do
    assert_dom_equal(
      "<option value=\"&lt;Abe&gt;\" disabled=\"disabled\">&lt;Abe&gt; went home</option>\n<option value=\"Babe\">Babe went home</option>\n<option value=\"Cabe\">Cabe went home</option>",
      options_from_collection_for_select(@posts, "author_name", "title", nil, lambda{|p| p.private_post == true })
    )
  end
  
  test "collection options with proc for selected" do
    assert_dom_equal(
      "<option value=\"&lt;Abe&gt;\" selected=\"selected\">&lt;Abe&gt; went home</option>\n<option value=\"Babe\">Babe went home</option>\n<option value=\"Cabe\">Cabe went home</option>",
      options_from_collection_for_select(@posts, "author_name", "title", lambda{|p| p.author_name == '<Abe>' })
    )
  end

end
