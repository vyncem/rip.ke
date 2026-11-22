# frozen_string_literal: true

class HomesController < ApplicationController
  PUBLISHER_EMAILS = %w[oliviamuia09@gmail.com vyncem@gmail.com].freeze

  skip_before_action :authenticate_user!, only: :verified
  skip_before_action :verify_authenticity_token, only: :verified

  # GET /homes
  def index
    @pull_requests = ghs.open_pull_requests
    @payee = '254'
    # @payee = ENV.fetch('DARAJA_PAYER', nil)
    @reply = params[:reply]
  end

  def check
    # if ['oliviamuia09@gmail.com', 'vyncem@gmail.com', 'nataliejeropbullut@gmail.com'].include?(current_user.email)
    # message = ghs.merge_pull_request(params[:home_id])

    if params[:reply].include?('ws_')
      message = JSON.parse(MpesaQueryService.new(id: params[:reply].split('-')[1], payer: ENV.fetch('DARAJA_PAYER', nil),
                                                 payee: ENV.fetch('DARAJA_SHORT_CODE', nil)).call)
    end

    redirect_to controller: :homes, action: :index, reply: (message && message['errorMessage']) || (message && "#{message['ResultDesc']}-#{message['CheckoutRequestID']}") || 'No message'
  end

  def verified
    Rails.logger.info(params)
  end

  def merge
    message = ghs.merge_pull_request(params[:home_id])

    redirect_to controller: :homes, action: :index, reply: message
  end

  def publish
    unless PUBLISHER_EMAILS.include?(current_user.email)
      redirect_to homes_url, alert: 'You are not allowed to publish.'
      return
    end

    result = ghs.publish_pull_request(params[:home_id])
    if result && result[:merged]
      redirect_to homes_url, notice: 'Pull request was successfully published.'
    else
      redirect_to homes_url, alert: result&.[](:message).presence || 'The pull request could not be published.'
    end
  end

  def delete
    message = ghs.delete_content(params[:file], params[:image])

    redirect_to homes_url, notice: message
  end

  private

  def ghs
    @ghs ||= GithubService.new(current_user.id)
  end
end
