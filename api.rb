# frozen_string_literal: true

require 'jwt'
require_relative 'jwt_helper'
require 'httparty'
require_relative 'http'
require 'active_support'
require 'byebug'

# Get products
class StoreKitAPI
  attr_reader :private_key, :issuer_id, :endpoint, :key_id, :response

  ALGORITHM = 'ES256'
  HOST = 'https://api.appstoreconnect.apple.com%<endpoint>s'

  UnauthenticatedError = Class.new(StandardError)
  ForbiddenError = Class.new(StandardError)

  def initialize(private_key:, issuer_id:, endpoint:, key_id:)
    @issuer_id = issuer_id
    @endpoint = endpoint
    @private_key = OpenSSL::PKey.read(private_key)
    @key_id = key_id
  end

  def call
    puts "JWT: #{jwt}"
    puts "JWT Payload: #{payload}"
    puts "JWT Headers: #{headers}"

    @response = request!

    puts decoded_response
  end

  private

  def decoded_response
    response
  end

  def request!
    url = format(HOST, endpoint: endpoint)
    result = HTTP.get(url, headers: { 'Authorization' => "Bearer #{jwt}" })
    raise UnauthenticatedError if result.code == 401
    raise ForbiddenError if result.code == 403

    save_to_file!(result) if result['content-type'] == 'application/a-gzip'

    result.parsed_response
  end

  def save_to_file!(data)
    filename = File.join(Dir.pwd, 'downloads', "report-#{rand(999)}.gzip")

    File.open(filename, 'w') do |file|
      file.write(data)
    end
  end

  def jwt
    JWT.encode(
      payload,
      private_key,
      ALGORITHM,
      headers
    )
  end

  def headers
    { kid: key_id, typ: 'JWT' }
  end

  def payload
    {
      iss: issuer_id,
      iat: timestamp,
      exp: timestamp(1200),
      aud: 'appstoreconnect-v1',
      scope: [
        "GET #{endpoint}"
      ]
    }
  end

  def timestamp(seconds = 0)
    Time.now.to_i + seconds
  end
end
