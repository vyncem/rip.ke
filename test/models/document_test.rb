# frozen_string_literal: true

require 'test_helper'

class DocumentTest < ActiveSupport::TestCase
  test 'splits front matter from the body' do
    document = Document.from_github(
      kind: 'post',
      path: '_posts/2025-10-18-Richard_Muia.md',
      content: "---\nname: Richard Muia\nlayout: post\npic: /assets/images/richard.jpg\n---\n<p>Hello</p>\n"
    )

    assert_equal 'Richard Muia', document.title
    assert_equal 'post', document.layout
    assert_equal "<p>Hello</p>\n", document.body
    assert_equal({ 'pic' => '/assets/images/richard.jpg' }, document.extra_front_matter)
  end

  test 'keeps the existing name key and extra front matter when serializing' do
    document = Document.from_github(
      kind: 'post',
      path: '_posts/2025-10-18-Richard_Muia.md',
      content: "---\nname: Richard Muia\ndate: 2025-10-18\nlayout: post\npic: /assets/images/richard.jpg\n---\nbody\n"
    )
    document.title = 'Richard M. Muia'

    content = document.to_content

    assert_includes content, 'name: Richard M. Muia'
    assert_includes content, 'date: 2025-10-18'
    assert_includes content, 'pic: "/assets/images/richard.jpg"'
    refute_includes content, 'title: Richard M. Muia'
  end

  test 'generates a jekyll post filename' do
    document = Document.new(kind: 'post', title: 'A New Post', date: '2026-02-03')

    assert_equal '_posts/2026-02-03-a-new-post.md', document.generated_path
  end

  test 'generates a page filename and keeps the permalink' do
    document = Document.new(kind: 'page', title: 'About Us', layout: 'default', permalink: '/about', body: 'Hello')

    assert_equal '_pages/about-us.md', document.generated_path
    assert_includes document.to_content, 'permalink: "/about"'
  end

  test 'rejects invalid front matter yaml' do
    document = Document.new(kind: 'page', title: 'Broken', front_matter_yaml: 'foo: [')

    assert_not document.valid?
    assert document.errors[:front_matter_yaml].any?
  end
end
