# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class DocumentsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  class FakeGithubService
    attr_reader :writes, :deletes

    def initialize(files = [])
      @files = files
      @writes = []
      @deletes = []
    end

    def list(_kind)
      @files.map { |file| file.except(:content) }
    end

    def find(_kind, slug)
      @files.find { |file| file[:name] == slug || File.basename(file[:path]) == slug || File.basename(file[:path], '.*') == slug }
    end

    def write(path, content)
      @writes << [path, content]
    end

    def exists?(_path)
      false
    end

    def delete(path)
      @deletes << path
    end
  end

  setup do
    sign_in users(:one)

    @file = {
      name: 'Test_Post.md',
      path: '_posts/2026-01-02-Test_Post.md',
      sha: 'abc123',
      html_url: 'https://github.com/example/test',
      content: "---\ntitle: Test Post\nlayout: post\n---\nHello\n"
    }
    @service = FakeGithubService.new([@file])
  end

  test 'lists posts' do
    GithubService.stub(:new, @service) do
      get posts_url
    end

    assert_response :success
    assert_select 'h1', 'Posts'
    assert_select 'a', 'Test Post'
  end

  test 'lists pages' do
    GithubService.stub(:new, @service) do
      get pages_url
    end

    assert_response :success
    assert_select 'h1', 'Pages'
  end

  test 'renders a post' do
    GithubService.stub(:new, @service) do
      get post_url('2026-01-02-Test_Post')
    end

    assert_response :success
    assert_select 'h1', 'Test Post'
    assert_includes response.body, 'Hello'
  end

  test 'renders the new post form' do
    GithubService.stub(:new, @service) do
      get new_post_url
    end

    assert_response :success
    assert_select 'form'
  end

  test 'creates a post' do
    GithubService.stub(:new, @service) do
      post posts_url, params: {
        document: { title: 'Another Post', date: '2026-02-03', layout: 'post', body: 'Body text' }
      }
    end

    assert_redirected_to post_url('2026-02-03-another-post')
    assert_equal 1, @service.writes.size
    path, content = @service.writes.first
    assert_equal '_posts/2026-02-03-another-post.md', path
    assert_includes content, 'title: Another Post'
    assert_includes content, 'Body text'
  end

  test 'does not overwrite an existing post' do
    @service.define_singleton_method(:exists?) { |_path| true }

    GithubService.stub(:new, @service) do
      post posts_url, params: {
        document: { title: 'Another Post', date: '2026-02-03', layout: 'post', body: 'Body text' }
      }
    end

    assert_response :unprocessable_entity
    assert_empty @service.writes
  end

  test 'updates a post without changing its path' do
    GithubService.stub(:new, @service) do
      patch post_url('2026-01-02-Test_Post'), params: {
        document: { title: 'Updated Post', date: '2026-01-02', layout: 'post', body: 'Updated body' }
      }
    end

    assert_redirected_to post_url('2026-01-02-Test_Post')
    assert_equal 1, @service.writes.size
    path, content = @service.writes.first
    assert_equal '_posts/2026-01-02-Test_Post.md', path
    assert_includes content, 'title: Updated Post'
    assert_includes content, 'Updated body'
  end

  test 'deletes a post' do
    GithubService.stub(:new, @service) do
      delete post_url('2026-01-02-Test_Post')
    end

    assert_redirected_to posts_url
    assert_equal ['_posts/2026-01-02-Test_Post.md'], @service.deletes
  end
end
