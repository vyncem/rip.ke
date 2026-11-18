# frozen_string_literal: true

# Thin wrapper around the GitHub API for the Jekyll content that powers the
# site. Content is edited on a per-user draft branch and proposed to the base
# branch through a pull request.
class GithubService
  attr_reader :client

  REPO = ENV.fetch('GITHUB_REPO', 'rip-coke/rip')
  BASE_BRANCH = ENV.fetch('BASE_BRANCH', 'master')
  BRANCH = 'draft'
  POSTS_FOLDER = ENV.fetch('POSTS_FOLDER', '_posts')
  PAGES_FOLDER = ENV.fetch('PAGES_FOLDER', '_pages')
  FOLDERS = { 'post' => POSTS_FOLDER, 'page' => PAGES_FOLDER }.freeze

  def initialize(id)
    @client = Octokit::Client.new(access_token: ENV.fetch('GITHUB_TOKEN', nil))
    @id = id
  end

  # Writes an image from a local path to the repository.
  def write_image(file_path_and_name, image_file)
    content = Base64.strict_encode64(File.binread(image_file))
    write(file_path_and_name, content, 'base64')
  end

  # Creates or updates a file on the user's draft branch.
  #
  # `content` is a normal String. Pass an encoding of `base64` when the caller
  # already has base64-encoded binary data (for example an uploaded image).
  def write(file_path_and_name, content, encoding = 'utf-8')
    data = encoding.to_s == 'base64' ? Base64.decode64(content.to_s) : content.to_s

    create_branch unless branch_exists?

    existing = file_info(file_path_and_name)
    if existing
      client.update_contents(REPO, file_path_and_name, "Update #{file_path_and_name}", existing.sha, data,
                             branch: user_branch)
    else
      client.create_contents(REPO, file_path_and_name, "Add #{file_path_and_name}", data, branch: user_branch)
    end
  end

  # All posts in the Jekyll `_posts` folder.
  def posts
    list(:post)
  end

  # All pages in the Jekyll `_pages` folder.
  def pages
    list(:page)
  end

  # Lists the files in one of the content folders.
  #
  # Returns an array of hashes with `:name`, `:path`, `:sha`, `:size` and
  # `:html_url`. The draft branch is used when it exists so that unpublished
  # edits are visible, otherwise the base branch is read.
  def list(kind)
    response = client.contents(REPO, path: folder_for(kind), ref: working_ref)
    return [] unless response.is_a?(Array)

    response.select { |item| item.type == 'file' }.map do |item|
      {
        name: item.name,
        path: item.path,
        sha: item.sha,
        size: item.size,
        html_url: item.html_url
      }
    end
  rescue Octokit::NotFound
    []
  end

  # Finds a post or page by its filename (with or without the extension) and
  # returns its metadata plus decoded `:content`.
  def find(kind, slug)
    slug = slug.to_s
    file = list(kind).find do |item|
      item[:path] == slug || item[:name] == slug || File.basename(item[:path], '.*') == slug
    end
    return unless file

    content = read(file[:path])
    return if content.nil?

    file.merge(content: content)
  end

  # Reads and decodes a file from the draft branch (or the base branch when no
  # draft exists yet).
  def read(path, ref = nil)
    file = client.contents(REPO, path: path, ref: ref || working_ref)
    return unless file.respond_to?(:content) && file.content

    if file.respond_to?(:encoding) && file.encoding.to_s == 'none'
      file.content
    else
      Base64.decode64(file.content)
    end
  rescue Octokit::NotFound
    nil
  end

  # Deletes a single file from the draft branch.
  def delete(path)
    return if path.blank?

    create_branch unless branch_exists?

    info = file_info(path)
    return unless info

    client.delete_contents(REPO, path, "Delete #{path}", info.sha, branch: user_branch)
  end

  # Returns true when a file already exists on the working branch.
  def exists?(path)
    file_info(path, working_ref).present?
  end

  # Kept for backwards compatibility with the notice form, which can reference
  # a markdown file and an image. Any argument may be nil.
  def delete_content(*paths)
    paths.flatten.compact.uniq.map { |path| delete(path) }.last
  end

  def pull_requests
    return [] unless branch_exists?

    unless compare_ahead?
      begin
        client.create_pull_request(REPO, BASE_BRANCH, user_branch, "#{BASE_BRANCH} < #{user_branch}")
      rescue Octokit::UnprocessableEntity
        # A pull request for this branch already exists.
      end
    end

    client.pull_requests(REPO).select { |pr| pr[:head][:ref] == user_branch }.map do |pull_request|
      pull_request_content(pull_request)
    end
  rescue Octokit::NotFound
    []
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
    return if compare_ahead?

    client.merge_pull_request(REPO, pull_request_number, "#{BASE_BRANCH} < #{user_branch}")
  end

  def compare_ahead?
    return true unless branch_exists?

    client.compare(REPO, BASE_BRANCH, user_branch)[:ahead_by].zero?
  rescue Octokit::NotFound
    true
  end

  def user_branch
    "#{@id}_#{BRANCH}"
  end

  def branch_exists?
    client.branch(REPO, user_branch).present?
  rescue Octokit::NotFound
    false
  end

  def create_branch
    base_branch_ref_sha = client.ref(REPO, "heads/#{BASE_BRANCH}").object.sha
    client.create_ref(REPO, "heads/#{user_branch}", base_branch_ref_sha)
  rescue Octokit::UnprocessableEntity
    # The branch already exists.
    nil
  end

  private

  def folder_for(kind)
    FOLDERS.fetch(kind.to_s) do
      raise ArgumentError, "Unknown content kind: #{kind}"
    end
  end

  # Prefer the user's draft branch so that saved-but-unmerged edits are shown.
  def working_ref
    branch_exists? ? user_branch : BASE_BRANCH
  end

  def file_info(path, ref = user_branch)
    info = client.contents(REPO, path: path, ref: ref)
    info if info.respond_to?(:sha) && info.type == 'file'
  rescue Octokit::NotFound
    nil
  end
end
