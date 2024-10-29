# frozen_string_literal: true

class MpesasController < ApplicationController
  def index
    @mpesas = params.merge(call_mpesa) || []

    Rails.logger.info(@mpesas)

    redirect_to controller: :homes, action: :index, reply: @mpesas['errorMessage'] || "#{@mpesas['ResponseDescription']}-#{@mpesas['CheckoutRequestID']}"
  end
  alias create index

  private

  def call_mpesa
    JSON.parse(
      MpesaService.new(amount: 1, payer: ENV.fetch('DARAJA_PAYER', nil), payee: ENV.fetch('DARAJA_SHORT_CODE', nil)).call
    )
  end
end
