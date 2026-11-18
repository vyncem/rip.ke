# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class GithubServiceTest < ActiveSupport::TestCase
  FileInfo = Struct.new(:name, :path, :sha, :size, :html_url, :type, :content, :encoding, keyword_init: true)

  class FakeClient
    attr_reader :calls

    def initialize(files = nil)
      @files = files
      @calls = []
    end

    def contents(_repo, options = {})
      @calls << [:contents, options]
      raise Octokit::NotFound if @files.nil?

      @files
    end

    def create_contents(*args)
      @calls << [:create_contents, args]
      :created
    end

    def update_contents(*args)
      @calls << [:update_contents, args]
      :updated
    end

    def delete_contents(*args)
      @calls << [:delete_contents, args]
      :deleted
    end
  end

  setup do
    @service = GithubService.new('user')
    @client = FakeClient.new
    @service.instance_variable_set(:@client, @client)
  end

  test 'creates a file when it does not exist' do
    result = @service.stub(:branch_exists?, true) do
      @service.write('_posts/2026-01-01-test.md', 'content')
    end

    assert_equal :created, result
    call = @client.calls.find { |name, _| name == :create_contents }
    assert_equal ['rip-coke/rip', '_posts/2026-01-01-test.md', 'Add _posts/2026-01-01-test.md', 'content',
                  { branch: 'user_draft' }], call.last
  end

  test 'updates a file when it already exists' do
    @client = FakeClient.new(FileInfo.new(type: 'file', sha: 'abc'))
    @service.instance_variable_set(:@client, @client)

    result = @service.stub(:branch_exists?, true) do
      @service.write('_posts/2026-01-01-test.md', 'new content')
    end

    assert_equal :updated, result
    call = @client.calls.find { |name, _| name == :update_contents }
    assert_equal 'abc', call.last[3]
    assert_equal 'new content', call.last[4]
  end

  test 'deletes an existing file' do
    @client = FakeClient.new(FileInfo.new(type: 'file', sha: 'abc'))
    @service.instance_variable_set(:@client, @client)

    result = @service.stub(:branch_exists?, true) do
      @service.delete('_posts/2026-01-01-test.md')
    end

    assert_equal :deleted, result
    call = @client.calls.find { |name, _| name == :delete_contents }
    assert_equal ['rip-coke/rip', '_posts/2026-01-01-test.md', 'Delete _posts/2026-01-01-test.md', 'abc',
                  { branch: 'user_draft' }], call.last
  end

  test 'lists only files' do
    files = [
      FileInfo.new(name: 'one.md', path: '_posts/one.md', sha: '1', type: 'file', html_url: 'url'),
      FileInfo.new(name: 'images', path: '_posts/images', sha: '2', type: 'dir', html_url: 'url')
    ]
    @client = FakeClient.new(files)
    @service.instance_variable_set(:@client, @client)

    result = @service.stub(:branch_exists?, false) do
      @service.posts
    end

    assert_equal 1, result.size
    assert_equal '_posts/one.md', result.first[:path]
  end

  test 'finds a page by its filename without the extension' do
    files = [FileInfo.new(name: 'about.html', path: '_pages/about.html', sha: '1', type: 'file')]
    @client = FakeClient.new(files)
    @service.instance_variable_set(:@client, @client)

    @service.stub(:branch_exists?, false) do
      # The second contents call is the file read.
      @client.define_singleton_method(:contents) do |_repo, options = {}|
        @calls << [:contents, options]
        if options[:path] == '_pages/about.html'
          FileInfo.new(type: 'file', content: Base64.strict_encode64("---\nlayout: default\n---\nBody"), encoding: 'base64')
        else
          files
        end
      end

      page = @service.find(:page, 'about')
      assert_equal '_pages/about.html', page[:path]
      assert_equal "---\nlayout: default\n---\nBody", page[:content]
    end
  end
end
