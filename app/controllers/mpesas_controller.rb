# frozen_string_literal: true
class MpesasController < ApplicationController
  def index
    @mpesas = params || []

    Rails.logger.info(@mpesas)
  end
  alias create index
end
