# frozen_string_literal: true

require 'base64'
include Rails.application.routes.url_helpers

class MpesaQueryService
  BASE_URL = Rails.env == 'development' ? 'https://sandbox.safaricom.co.ke' : 'https://api.safaricom.co.ke'

  def initialize(id:, payer:, payee:)
    @id = id
    @payer = payer
    @payee = payee
  end

  def call
    conn.post('mpesa/stkpushquery/v1/query') do |req|
      req.body = body.to_json
    end.body
  end

  private

  def token
    JSON.parse(oauth)['access_token']
  end

  def oauth
    conn_basic.get('/oauth/v1/generate').body
  end

  def conn
    Faraday.new(url: BASE_URL, headers:) do |conn|
      conn.request(:authorization, 'Bearer', token)
    end
  end

  def conn_basic
    Faraday.new(url: BASE_URL, params:) do |conn|
      conn.request(:authorization, :basic, ENV.fetch('DARAJA_KEY', nil), ENV.fetch('DARAJA_SECRET', nil))
    end
  end

  def params
    { grant_type: 'client_credentials' }
  end

  def headers
    { 'Content-Type': 'application/json' }
  end

  def timestamp
    Time.now.strftime('%Y%m%d%H%M%S')
  end

  def body
    {
      BusinessShortCode: @payee,
      Password: Base64.strict_encode64(@payee.to_s + ENV.fetch('DARAJA_PASS_KEY', nil) + timestamp),
      Timestamp: timestamp,
      CheckoutRequestID: @id
    }
  end
end
