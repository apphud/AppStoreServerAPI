# frozen_string_literal: true

require 'jwt'
require_relative 'jwt_helper'
require 'httparty'
require_relative 'http'
require 'active_support'
require 'byebug'

class StoreKit
  attr_reader :private_key, :issuer_id, :original_transaction_id, :key_id, :bundle_id, :response

  ALGORITHM = 'ES256'
  URL = 'https://api.storekit-sandbox.itunes.apple.com/inApps/v1/subscriptions/%<original_transaction_id>s'

  UnauthenticatedError = Class.new(StandardError)
  ForbiddenError = Class.new(StandardError)

  def initialize(private_key:, issuer_id:, original_transaction_id:, key_id:, bundle_id:)
    @issuer_id = issuer_id
    @original_transaction_id = original_transaction_id
    @private_key = OpenSSL::PKey.read(private_key)
    @key_id = key_id
    @bundle_id = bundle_id
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
    response['data'].each do |item|
      item['lastTransactions'].each do |t|
        t['signedTransactionInfo'] = JWTHelper.decode(t['signedTransactionInfo'])
        t['signedRenewalInfo'] = JWTHelper.decode(t['signedRenewalInfo'])
      end
    end

    response
  end

  def request!
    url = format(URL, original_transaction_id: original_transaction_id)
    result = HTTP.get(url, headers: { 'Authorization' => "Bearer #{jwt}" })
    # raise UnauthenticatedError if result.code == 401
    # raise ForbiddenError if result.code == 403

    result.parsed_response
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
      exp: timestamp(1800),
      aud: 'appstoreconnect-v1',
      nonce: SecureRandom.uuid,
      bid: bundle_id
    }
  end

  def timestamp(seconds = 0)
    Time.now.to_i + seconds
  end
end
