# frozen_string_literal: true

require 'base64'
include Rails.application.routes.url_helpers

class MpesaService
  BASE_URL = 'https://sandbox.safaricom.co.ke'

  def initialize(amount:, payer:, payee:)
    @amount = amount
    @payer = payer
    @payee = payee
  end

  def call
    conn.post('/mpesa/stkpush/v1/processrequest') do |req|
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
      # conn.request(:authorization, 'Bearer', Base64.encode64("#{ENV['DARAJA_KEY']}:#{ENV['DARAJA_SECRET']}").gsub("\n",''))
    end
  end

  def params
    { grant_type: 'client_credentials' }
  end

  def headers
    { 'Content-Type': 'application/json' }
  end

  def body # rubocop:disable Metrics/MethodLength
    {
      BusinessShortCode: @payee,
      Password: 'MTc0Mzc5YmZiMjc5ZjlhYTliZGJjZjE1OGU5N2RkNzFhNDY3Y2QyZTBjODkzMDU5YjEwZjc4ZTZiNzJhZGExZWQyYzkxOTIwMjQwMTE1MTk0MTQ3', # base64.encode(Shortcode+Passkey+Timestamp)
      Timestamp: '20240115194147', # YYYYMMDDHHmmss
      TransactionType: 'CustomerPayBillOnline',
      Amount: @amount,
      PartyA: @payer,
      PartyB: @payee,
      PhoneNumber: @payer,
      CallBackURL: mpesas_url,
      AccountReference: 'CompanyXLTD',
      TransactionDesc: 'Payment of X'
    }
  end
end
