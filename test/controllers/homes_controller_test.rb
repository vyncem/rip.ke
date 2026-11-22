require 'test_helper'
require 'minitest/mock'

class HomesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  class FakeGithubService
    attr_accessor :open_pull_requests
    attr_reader :merges

    def initialize
      @open_pull_requests = []
      @merges = []
    end

    def publish_pull_request(id)
      @merges << id
      { merged: true }
    end

    def open_pull_requests
      @open_pull_requests
    end
  end

  setup do
    sign_in users(:one)
  end

  test 'shows the draft dashboard without notice creation controls' do
    GithubService.stub(:new, FakeGithubService.new) do
      get homes_url
    end

    assert_response :success
    assert_select 'h1', 'Drafts'
    assert_select 'a', text: 'Drafts'
    assert_select 'a', text: 'Notices', count: 0
    assert_select 'a', text: 'New notice', count: 0
  end

  test 'lists open publishings from other users' do
    service = FakeGithubService.new
    service.open_pull_requests = [{
      id: '42',
      url: 'https://github.com/rip-coke/rip/pull/42',
      title: 'Another user draft',
      branch: 'another-user_draft',
      files: [],
      text: []
    }]

    GithubService.stub(:new, service) do
      get homes_url
    end

    assert_response :success
    assert_select 'h2', 'Another user draft'
    assert_select 'a[href^="https://github.com"]', count: 0
    assert_select 'a', text: 'Another user draft', count: 0
    assert_select 'form[action=?]', home_publish_path('42'), count: 0
  end

  test 'shows the publish button for publishers and merges the selected pull request' do
    user = users(:one)
    user.update!(email: 'vyncem@gmail.com')
    service = FakeGithubService.new
    service.open_pull_requests = [{
      id: '42',
      url: 'https://github.com/rip-coke/rip/pull/42',
      title: 'Another user draft',
      branch: 'another-user_draft',
      files: [],
      text: []
    }]

    GithubService.stub(:new, service) do
      get homes_url
    end

    assert_select 'form[action=?]', home_publish_path('42')

    GithubService.stub(:new, service) do
      post home_publish_url('42')
    end

    assert_redirected_to homes_url
    assert_equal ['42'], service.merges
    assert_equal 'Pull request was successfully published.', flash[:notice]
  end

  test 'does not allow non-publishers to publish publishings' do
    service = FakeGithubService.new

    GithubService.stub(:new, service) do
      post home_publish_url('42')
    end

    assert_redirected_to homes_url
    assert_empty service.merges
    assert_equal 'You are not allowed to publish.', flash[:alert]
  end

  test 'does not expose the notice CRUD routes' do
    get '/homes/new'
    assert_response :not_found

    post '/upload'
    assert_response :not_found
  end
end
