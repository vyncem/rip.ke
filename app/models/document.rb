# frozen_string_literal: true

# A Jekyll post or page stored in GitHub rather than the local database.
#
# The model knows how to split a markdown file into YAML front matter and a
# body, and how to put it back together. It intentionally keeps the original
# front matter so fields that the UI does not expose (images, excerpts,
# headers, etc.) are not lost when a document is edited.
class Document
  include ActiveModel::Model
  include ActiveModel::Attributes

  KINDS = %w[post page].freeze
  FRONT_MATTER_PATTERN = /\A---\s*\r?\n(.*?)\r?\n---\s*\r?\n?(.*)\z/m
  MANAGED_FRONT_MATTER_KEYS = %w[title name date layout permalink].freeze

  attribute :kind, :string
  attribute :path, :string
  attribute :title, :string
  attribute :date, :string
  attribute :layout, :string
  attribute :permalink, :string
  attribute :body, :string, default: ''
  attribute :front_matter_yaml, :string, default: ''
  attribute :sha, :string
  attribute :html_url, :string

  validates :kind, inclusion: { in: KINDS }
  validates :title, presence: true
  validates :date, presence: true, if: -> { kind.to_s == 'post' }
  validate :date_must_be_valid
  validate :front_matter_must_be_a_mapping

  class << self
    def from_github(kind:, path:, content:, sha: nil, html_url: nil)
      front_matter, body = split(content.to_s)
      title_key = front_matter.key?('name') && !front_matter.key?('title') ? 'name' : 'title'

      new(
        kind: kind.to_s,
        path: path,
        title: front_matter[title_key].to_s.presence || title_from_path(path),
        date: normalize_date(front_matter['date']) || date_from_path(path),
        layout: front_matter['layout'].to_s,
        permalink: front_matter['permalink'].to_s,
        body: body,
        front_matter_yaml: dump_front_matter(front_matter),
        sha: sha,
        html_url: html_url
      )
    end

    # Splits a Jekyll document into a front matter hash and body.
    def split(content)
      match = content.match(FRONT_MATTER_PATTERN)
      return [{}, content] unless match

      parsed = YAML.safe_load(match[1], permitted_classes: [Date, Time], aliases: true) || {}
      parsed = {} unless parsed.is_a?(Hash)

      [parsed.stringify_keys, match[2]]
    rescue Psych::Exception
      [{}, content]
    end

    def dump_front_matter(front_matter)
      return '' if front_matter.blank?

      YAML.dump(front_matter).sub(/\A---\s*\n/, '')
    end

    def title_from_path(path)
      name = File.basename(path.to_s, '.*').sub(/\A\d{4}-\d{2}-\d{2}-/, '')
      name.tr('_-', ' ').squish.sub(/\A./) { |first| first.upcase }
    end

    def date_from_path(path)
      File.basename(path.to_s)[/\A(\d{4}-\d{2}-\d{2})-/, 1]
    end

    def normalize_date(value)
      case value
      when Date, Time
        value.to_date.iso8601
      else
        value.to_s.presence
      end
    end

    def folder_for(kind)
      GithubService::FOLDERS.fetch(kind.to_s) do
        raise ArgumentError, "Unknown document kind: #{kind}"
      end
    end
  end

  def display_title
    title.presence || self.class.title_from_path(path)
  end

  def slug
    title.to_s.parameterize.presence ||
      self.class.title_from_path(path).parameterize.presence ||
      'untitled'
  end

  # Filename used when a new document is first saved. Posts follow Jekyll's
  # `YYYY-MM-DD-title.md` convention; pages are saved as markdown.
  def generated_path
    folder = self.class.folder_for(kind)

    if kind.to_s == 'post'
      "#{folder}/#{date.presence || Date.current.iso8601}-#{slug}.md"
    else
      "#{folder}/#{slug}.md"
    end
  end

  # Serializes the document back to a Jekyll markdown file.
  def to_content
    front_matter = parsed_front_matter

    update_title(front_matter)
    front_matter['date'] = jekyll_date if kind.to_s == 'post' && date.present?
    front_matter['layout'] = layout if layout.present?
    front_matter['permalink'] = permalink if kind.to_s == 'page' && permalink.present?

    "#{YAML.dump(front_matter)}---\n#{body}"
  end

  def persisted?
    sha.present?
  end

  def id
    File.basename(path.to_s, '.*')
  end
  alias to_param id

  # Front matter fields that the form does not render directly. Exposed in the
  # UI so custom keys can still be edited.
  def extra_front_matter
    parsed_front_matter.except(*MANAGED_FRONT_MATTER_KEYS)
  end

  private

  def update_title(front_matter)
    return if title.blank?

    # Some existing posts use `name` instead of `title`. Keep whichever key
    # the document already uses so the Jekyll layouts continue to work.
    if front_matter.key?('name') && !front_matter.key?('title')
      front_matter['name'] = title
    else
      front_matter['title'] = title
    end
  end

  # Parsing the form date and dumping it back as a Date keeps the YAML
  # unquoted, which is the format Jekyll's date filters expect.
  def jekyll_date
    Date.parse(date.to_s)
  rescue Date::Error
    date
  end

  def parsed_front_matter
    return {} if front_matter_yaml.blank?

    parsed = YAML.safe_load(front_matter_yaml, permitted_classes: [Date, Time], aliases: true)
    parsed.is_a?(Hash) ? parsed.stringify_keys : {}
  end

  def front_matter_must_be_a_mapping
    return if front_matter_yaml.blank?

    parsed = YAML.safe_load(front_matter_yaml, permitted_classes: [Date, Time], aliases: true)
    return if parsed.nil? || parsed.is_a?(Hash)

    errors.add(:front_matter_yaml, 'must be a YAML mapping')
  rescue Psych::Exception => e
    errors.add(:front_matter_yaml, "is invalid YAML: #{e.message}")
  end

  def date_must_be_valid
    return if date.blank?

    Date.parse(date.to_s)
  rescue Date::Error
    errors.add(:date, 'must be a valid date (YYYY-MM-DD)')
  end
end
