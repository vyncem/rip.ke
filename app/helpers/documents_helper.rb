# frozen_string_literal: true

module DocumentsHelper
  def document_index_path(kind = @kind)
    kind.to_s == 'page' ? pages_path : posts_path
  end

  def new_document_path(kind = @kind)
    kind.to_s == 'page' ? new_page_path : new_post_path
  end

  def document_show_path(document)
    document.kind.to_s == 'page' ? page_path(document) : post_path(document)
  end

  def edit_document_path(document)
    document.kind.to_s == 'page' ? edit_page_path(document) : edit_post_path(document)
  end

  def publish_document_path(document)
    document.kind.to_s == 'page' ? publish_page_path(document) : publish_post_path(document)
  end

  def document_kind_label(kind = @kind)
    kind.to_s == 'page' ? 'Page' : 'Post'
  end
end
