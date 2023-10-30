# frozen_string_literal: true

module HomesHelper
  def call_mpesa
    MpesaService.new(amount: 1, payer: 254_708_374_149, payee: 174_379).call
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
