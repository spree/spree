require 'test/unit'
require File.dirname(__FILE__) + '/../test_helper'
require 'sass/css'

class CSS2SassTest < Test::Unit::TestCase
  def test_basic
    css = <<CSS
h1 {
  color: red;
}
CSS
    assert_equal(<<SASS, css2sass(css))
h1
  :color red
SASS
    assert_equal(<<SASS, css2sass(css, :alternate => true))
h1
  color: red
SASS
  end

  def test_nesting
    assert_equal(<<SASS, css2sass(<<CSS))
li
  :display none

  a
    :text-decoration none

    span
      :color yellow

    &:hover
      :text-decoration underline
SASS
li {
  display: none;
}

li a {
  text-decoration: none;
}

li a span {
  color: yellow;
}

li a:hover {
  text-decoration: underline;
}
CSS
  end

  def test_comments_multiline
    css = <<CSS
/* comment */
elephant.rawr {
  rampages: excessively;
}

/* actual multiline
  comment */
span.turkey {
  isdinner: true;
}

.turducken {
  /* Sounds funny
     doesn't it */
  chimera: not_really;
}

#overhere {
  bored: sorta; /* it's for a good
  cause */
  better_than: thread_pools;
}

#one_more {
  finally: srsly;
} /* just a line here */
CSS
    sass = <<SASS
elephant.rawr
  :rampages excessively


span.turkey
  :isdinner true


.turducken
  :chimera not_really


#overhere
  :bored sorta
  :better_than thread_pools


#one_more
  :finally srsly
SASS
    assert_equal(css2sass(css), sass)
  end

  def test_fold_commas
    assert_equal(<<SASS, css2sass(<<CSS))
li
  .one, .two
    :color red
SASS
li .one {
  color: red;
}
li .two {
  color: red;
}
CSS

    assert_equal(<<SASS, css2sass(<<CSS))
.one
  :color green


.two
  :color green
  :color red


.three
  :color red
SASS
.one, .two {
  color: green;
}

.two, .three {
  color: red;
}
CSS
  end

  def test_bad_formatting
    assert_equal(<<SASS, css2sass(<<CSS))
hello
  :parent true

  there
    :parent false

  who
    :hoo false

  why
    :y true

  when
    :wen nao


down_here
  :yeah true
SASS
hello {
  parent: true;
}

hello  there {
  parent: false;
}
hello who  {
  hoo: false;
}
hello why {
   y: true;
}
hello when {
  wen:  nao;
}



down_here { yeah: true; }
CSS
  end

  private

  def css2sass(string, opts={})
    Sass::CSS.new(string, opts).render
  end
end
