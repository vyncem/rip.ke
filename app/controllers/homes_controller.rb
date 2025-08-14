# frozen_string_literal: true

class HomesController < ApplicationController # rubocop:disable Metrics/ClassLength
  before_action :set_home, only: %i[show edit update destroy]

  # GET /homes or /homes.json
  def index
    @pull_requests = ghs.pull_requests
    @payee = '254'
    # @payee = ENV.fetch('DARAJA_PAYER', nil)
    @reply = params[:reply]
  end

  # GET /homes/1 or /homes/1.json
  def show; end

  # GET /homes/new
  def new
    @home = Home.new
  end

  # GET /homes/1/edit
  def edit; end

  def check
    # if ['oliviamuia09@gmail.com', 'vyncem@gmail.com', 'nataliejeropbullut@gmail.com'].include?(current_user.email)
    # message = ghs.merge_pull_request(params[:home_id])

    if params[:reply].include?('ws_')
      message = JSON.parse(MpesaQueryService.new(id: params[:reply].split('-')[1], payer: ENV.fetch('DARAJA_PAYER', nil),
                                                 payee: ENV.fetch('DARAJA_SHORT_CODE', nil)).call)
    end

    redirect_to controller: :homes, action: :index, reply: (message && message['errorMessage']) || (message && "#{message['ResultDesc']}-#{message['CheckoutRequestID']}") || 'No message'
  end

  def verify
    id = params[:id]
    uri = URI("https://api.paystack.co/transaction/verify/#{reference}")
    req = Net::HTTP::Get.new(uri)
    req['Authorization'] = "Bearer #{ENV['PAYSTACK_SECRET_KEY']}"
    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
    result = JSON.parse(res.body)
    if result['data'] && result['data']['status'] == 'success'
      flash[:notice] = "Payment successful!"
    else
      flash[:alert] = "Payment failed!"
    end
    redirect_to homes_path
  end

  def merge
    message = ghs.merge_pull_request(params[:home_id])

    redirect_to controller: :homes, action: :index, reply: message
  end

  def delete
    message = ghs.delete_content(params[:file], params[:image])

    redirect_to homes_url, notice: message
  end

  # POST /homes or /homes.json
  def create
    res = [res_txt, res_img]

    respond_to do |format|
      format.html { redirect_to homes_url, notice: "Notice was successfully created. #{res}" }
    end
  rescue StandardError => e
    respond_to do |format|
      format.html { redirect_to new_home_url, alert: e.message }
    end
  end

  # PATCH/PUT /homes/1 or /homes/1.json
  def update
    respond_to do |format|
      if @home.update(home_params)
        format.html { redirect_to home_url(@home), notice: 'Notice was successfully updated.' }
        format.json { render :show, status: :ok, location: @home }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @home.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /homes/1 or /homes/1.json
  def destroy
    @home.destroy!

    respond_to do |format|
      format.html { redirect_to homes_url, notice: 'Notice was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private

  def res_img
    ghs.write(image_name, content, 'base64')[:parents].second[:html_url]
  end

  def content
    image_file = Tempfile.new('foo', binmode: true)
    image_file.write(file.download)
    image_file.rewind
    resize_file = MiniMagick::Image.open(image_file.path)
    resize_file.resize '512x512!'
    content = Base64.strict_encode64(resize_file.to_blob)
    image_file.close
    image_file.unlink
    content
  end

  def image_name
    "assets/images/#{full_name}.#{file[:filename].split('.')[1]}"
  end

  def body
    home.content.body
  end

  def file
    body.attachments.first.attachable
  end

  def res_txt
    ghs.write("_notices/#{full_name}.md", text)[:parents].second[:html_url]
  end

  def full_name
    "#{dod}_#{dob}_#{name}".gsub('-', '_').gsub(' ', '_')
  end

  def name
    home_params.delete(:name)
  end

  def dob
    home_params.delete(:dob)
  end

  def dod
    home_params.delete(:dod)
  end

  def county
    home_params.delete(:county)
  end

  def home
    Home.new(home_params.except(:name, :dod, :dob, :county))
  end

  def text
    <<~TEXT
      ---
      name: #{name}
      dob: #{dob}
      dod: #{dod}
      county: #{county}
      pic: /#{image_name}
      user: #{current_user.id}
      layout: post
      ---
      <p class='py-2'>#{body.to_plain_text.gsub(/\[.*?\]/, '').gsub("\n", "</\p><p class='py-2'>")}</p>
    TEXT
  end

  def ghs
    @ghs ||= GithubService.new(current_user.id)
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_home
    @home = Home.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def home_params
    params.require(:home).permit(:content, :name, :dob, :dod, :county)
  end
end
