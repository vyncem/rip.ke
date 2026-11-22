# frozen_string_literal: true

# CRUD for the Jekyll posts and pages that live in the GitHub repository.
# The routes for both kinds point here with a `kind` default (see
# config/routes.rb).
class DocumentsController < ApplicationController
  rescue_from Octokit::Error, with: :handle_github_error

  before_action :set_kind
  before_action :set_document, only: %i[show edit update destroy publish]

  # GET /posts and GET /pages
  def index
    @documents = service.list(@kind).map do |file|
      Document.new(kind: @kind, path: file[:path], sha: file[:sha], html_url: file[:html_url])
    end
    @documents.sort_by! { |document| document.path.to_s }
    @documents.reverse! if @kind == 'post'
  end

  # GET /posts/:id and GET /pages/:id
  def show
    @publishable = publishable_pull_request.present?
  end

  # GET /posts/new and GET /pages/new
  def new
    @document = Document.new(kind: @kind, layout: default_layout)
    @document.date = Date.current.iso8601 if @kind == 'post'
  end

  # GET /posts/:id/edit and GET /pages/:id/edit
  def edit; end

  # POST /posts and POST /pages
  def create
    @document = Document.new(document_params)
    @document.kind = @kind
    @document.layout = default_layout if @document.layout.blank?
    @document.permalink = "/#{@document.slug}" if @kind == 'page' && @document.permalink.blank?
    @document.path = @document.generated_path

    if @document.valid? && service.exists?(@document.path)
      @document.errors.add(:base, "A #{kind_label.downcase} already exists at #{@document.path}")
      render :new, status: :unprocessable_entity
    elsif @document.valid?
      service.write(@document.path, @document.to_content)
      redirect_to show_url_for(@document), notice: "#{kind_label} was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /posts/:id and /pages/:id
  def update
    @document.assign_attributes(document_params)
    @document.layout = default_layout if @document.layout.blank?

    if @document.valid?
      service.write(@document.path, @document.to_content)
      redirect_to show_url_for(@document), notice: "#{kind_label} was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /posts/:id and DELETE /pages/:id
  def destroy
    service.delete(@document.path)
    redirect_to index_url_for_kind, notice: "#{kind_label} was successfully deleted."
  end

  def publish
    pull_request = publishable_pull_request
    unless pull_request
      redirect_to show_url_for(@document), alert: "No draft changes for this #{kind_label.downcase} to publish."
      return
    end

    result = service.merge_pull_request(pull_request[:id])
    if result && result[:merged]
      redirect_to show_url_for(@document), notice: "#{kind_label} was successfully published."
    else
      message = result&.[](:message).presence || 'The draft pull request could not be merged.'
      redirect_to show_url_for(@document), alert: message
    end
  end

  private

  def set_kind
    @kind = params[:kind].presence || 'post'
    return if Document::KINDS.include?(@kind)

    raise ActionController::RoutingError, "Unknown document kind: #{@kind}"
  end

  def set_document
    data = service.find(@kind, params[:id])
    raise ActiveRecord::RecordNotFound, "Couldn't find #{@kind} '#{params[:id]}'" unless data

    @document = Document.from_github(
      kind: @kind,
      path: data[:path],
      content: data[:content],
      sha: data[:sha],
      html_url: data[:html_url]
    )
  end

  def service
    @service ||= GithubService.new(current_user.id)
  end

  def publishable_pull_request
    service.pull_requests.find { |pull_request| pull_request[:files].include?(@document.path) }
  end

  def document_params
    params.require(:document).permit(:title, :date, :layout, :permalink, :body, :front_matter_yaml)
  end

  def default_layout
    if @kind == 'post'
      ENV.fetch('DEFAULT_POST_LAYOUT', 'post')
    else
      ENV.fetch('DEFAULT_PAGE_LAYOUT', 'default')
    end
  end

  def kind_label
    @kind == 'page' ? 'Page' : 'Post'
  end

  def show_url_for(document)
    @kind == 'page' ? page_url(document) : post_url(document)
  end

  def index_url_for_kind
    @kind == 'page' ? pages_url : posts_url
  end

  def handle_github_error(error)
    Rails.logger.error("[GitHub] #{error.class}: #{error.message}")

    case action_name
    when 'create'
      flash.now[:alert] = "GitHub error: #{error.message}"
      render :new, status: :unprocessable_entity
    when 'update'
      flash.now[:alert] = "GitHub error: #{error.message}"
      render :edit, status: :unprocessable_entity
    when 'publish'
      redirect_to show_url_for(@document), alert: "GitHub error: #{error.message}"
    when 'index'
      @documents = []
      flash.now[:alert] = "GitHub error: #{error.message}"
      render :index, status: :bad_gateway
    else
      redirect_to index_url_for_kind, alert: "GitHub error: #{error.message}"
    end
  end
end
