# frozen_string_literal: true

module HomesHelper
  def call_mpesa
    MpesaService.new(amount: 1, payer: ENV.fetch('DARAJA_PAYER', nil), payee: ENV.fetch('DARAJA_SHORT_CODE', nil)).call
  end

  def body_text(pull_request, index)
    pull_request[:text][index]&.gsub(/---\s?.+?---/m, '')&.gsub(/@@\s?.+?@@/m, '')&.gsub("<p class='py-2'></p>", '')&.gsub('+', '')&.html_safe
  end

  def name(pull_request, index)
    header_text(pull_request, index).split(':')[1].split('<br/>')[0] if header_text(pull_request, index)
  end

  def dob(pull_request, index)
    header_text(pull_request, index).split(':')[2].split('<br/>')[0] if header_text(pull_request, index)
  end

  def dod(pull_request, index)
    header_text(pull_request, index).split(':')[3].split('<br/>')[0] if header_text(pull_request, index)
  end

  def county(pull_request, index)
    header_text(pull_request, index).split(':')[4].split('<br/>')[0] if header_text(pull_request, index)
  end

  def header_text(pull_request, index)
    breaker = '---'
    pull_request[:text][index]&.gsub('+', ' <br/> ')&.html_safe&.[](/#{breaker}(.*?)#{breaker}/m, 1)
  end

  def counties # rubocop:disable Metrics/MethodLength
    [
      ['Nairobi', 'Nairobi'],
      ['Mombasa', 'Mombasa'],
      ['Machakos', 'Machakos'],
      ['Uasin Gishu', 'Uasin Gishu'],
      ['Kiambu', 'Kiambu'],
      ['Kwale', 'Kwale'],
      ['Kilifi', 'Kilifi'],
      ['Tana River', 'Tana River'],
      ['Lamu', 'Lamu'],
      ['Taita/Taveta', 'Taita/Taveta'],
      ['Garissa', 'Garissa'],
      ['Wajir', 'Wajir'],
      ['Mandera', 'Mandera'],
      ['Marsabit', 'Marsabit'],
      ['Isiolo', 'Isiolo'],
      ['Meru', 'Meru'],
      ['Tharaka-Nithi', 'Tharaka-Nithi'],
      ['Embu', 'Embu'],
      ['Kitui', 'Kitui'],
      ['Makueni', 'Makueni'],
      ['Nyandarua', 'Nyandarua'],
      ['Nyeri', 'Nyeri'],
      ['Kirinyaga', 'Kirinyaga'],
      ["Murang'a", "Murang'a"],
      ['Turkana', 'Turkana'],
      ['West Pokot', 'West Pokot'],
      ['Samburu', 'Samburu'],
      ['Trans Nzoia', 'Trans Nzoia'],
      ['Elgeyo/Marakwet', 'Elgeyo/Marakwet'],
      ['Nandi', 'Nandi'],
      ['Baringo', 'Baringo'],
      ['Laikipia', 'Laikipia'],
      ['Nakuru', 'Nakuru'],
      ['Narok', 'Narok'],
      ['Kajiado', 'Kajiado'],
      ['Kericho', 'Kericho'],
      ['Bomet', 'Bomet'],
      ['Kakamega', 'Kakamega'],
      ['Vihiga', 'Vihiga'],
      ['Bungoma', 'Bungoma'],
      ['Busia', 'Busia'],
      ['Siaya', 'Siaya'],
      ['Kisumu', 'Kisumu'],
      ['Homa Bay', 'Homa Bay'],
      ['Migori', 'Migori'],
      ['Kisii', 'Kisii'],
      ['Nyamira', 'Nyamira']
    ]
  end
end
