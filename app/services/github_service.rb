# frozen_string_literal: true

class GithubService
  attr_reader :client

  # REPO = 'vyncem/test_repo'
  REPO = 'rip-coke/rip'
  BASE_BRANCH = ENV.fetch('BASE_BRANCH', 'master')
  BRANCH = 'draft'

  def initialize(id)
    @client = Octokit::Client.new(access_token: ENV.fetch('GITHUB_TOKEN', nil))
    @id = id
  end

  def write_image(file_path_and_name, image_file)
    content = Base64.strict_encode64(File.binread(image_file))
    write(file_path_and_name, content, 'base64')
  end

  def write(file_path_and_name, content, encoding = 'utf-8')
    blob = client.create_blob(REPO, content, encoding)

    options = {
      path: file_path_and_name,
      mode: '100644',
      type: 'blob',
      sha: blob
    }
    tree = client.create_tree(REPO, [options])

    commit = client.create_commit(REPO, file_path_and_name, tree.sha)
    
    create_branch
    client.merge(REPO, user_branch, commit.sha)
  end

  def pull_requests
    begin
      client.create_pull_request(REPO, BASE_BRANCH, user_branch, "#{BASE_BRANCH} < #{user_branch}") unless compare_ahead?
    rescue StandardError => e
      e
    end

    client.pull_requests(REPO).select { |pr| pr[:head][:ref] == user_branch }.map do |pull_request|
      pull_request_content(pull_request)
    end
  end

  def pull_request_content(pull_request)
    url = pull_request[:url]
    pull_request_number = url.split('/').last
    pull_request_files = pull_request_files(pull_request_number)

    {
      id: pull_request_number,
      url: pull_request[:url],
      files: pull_request_files.map(&:filename),
      text: pull_request_files.map(&:patch)
    }
  end

  def pull_request_files(pull_request_number)
    client.pull_request_files(REPO, pull_request_number)
  end

  def merge_pull_request(pull_request_number)
    client.merge_pull_request(REPO, pull_request_number, "#{BASE_BRANCH} < #{user_branch}") unless pull_requests.blank?
  end

  def compare_ahead?
    client.compare(REPO, BASE_BRANCH, user_branch)[:ahead_by].zero?
  end

  def delete_content(image, file)
    sha = client.contents(REPO, path: file, ref: user_branch)[:sha]
    client.delete_contents(REPO, file, 'Delete', sha, branch: user_branch)[:commit][:sha]

    sha = client.contents(REPO, path: image, ref: user_branch)[:sha]
    client.delete_contents(REPO, image, 'Delete', sha, branch: user_branch)[:commit][:sha]
  end

  def user_branch
    "#{@id}_#{BRANCH}"
  end

  def create_branch
    begin
      base_branch_ref_sha = client.ref(REPO, "heads/#{BASE_BRANCH}").object.sha
      client.create_ref(REPO, "heads/#{user_branch}", base_branch_ref_sha)
    rescue StandardError => e
      e
    end
  end
end
