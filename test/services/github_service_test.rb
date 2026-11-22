# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class GithubServiceTest < ActiveSupport::TestCase
  FileInfo = Struct.new(:name, :path, :sha, :size, :html_url, :type, :content, :encoding, keyword_init: true)
  PullRequestFile = Struct.new(:filename, :patch)

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

    def merge_pull_request(*args)
      @calls << [:merge_pull_request, args]
      :merged
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
    assert_equal [GithubService::REPO, '_posts/2026-01-01-test.md', 'Add _posts/2026-01-01-test.md', 'content',
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
    assert_equal [GithubService::REPO, '_posts/2026-01-01-test.md', 'Delete _posts/2026-01-01-test.md', 'abc',
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

  test 'lists all open pull requests regardless of branch owner' do
    pull_request = {
      url: 'https://api.github.com/repos/rip-coke/rip/pulls/42',
      title: 'A draft from another user',
      head: { ref: 'another-user_draft' }
    }
    @client.define_singleton_method(:pull_requests) do |repo, options|
      @calls << [:pull_requests, repo, options]
      [pull_request]
    end
    @client.define_singleton_method(:pull_request_files) do |_repo, number|
      @calls << [:pull_request_files, number]
      [PullRequestFile.new('_posts/draft.md', '+++')]
    end

    result = @service.open_pull_requests

    assert_equal '42', result.first[:id]
    assert_equal 'A draft from another user', result.first[:title]
    assert_equal 'another-user_draft', result.first[:branch]
    assert_equal ['_posts/draft.md'], result.first[:files]
    assert_includes @client.calls, [:pull_requests, GithubService::REPO, { state: 'open' }]
  end

  test 'publishes the requested pull request' do
    result = @service.publish_pull_request('42')

    assert_equal :merged, result
    assert_equal [GithubService::REPO, '42', 'Publish pull request #42'],
                 @client.calls.find { |call| call.first == :merge_pull_request }.last
  end

  test 'only includes files from the signed-in user branch as publishable' do
    own_pull_request = { branch: 'user_draft', files: ['_posts/own.md'] }

    @service.stub(:user_pull_requests, [own_pull_request]) do
      assert_equal ['_posts/own.md'], @service.publishable_paths
      assert_equal own_pull_request, @service.pull_request_for_path('_posts/own.md')
      assert_nil @service.pull_request_for_path('_posts/other.md')
    end
  end
end
