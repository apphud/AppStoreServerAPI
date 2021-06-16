# frozen_string_literal: true

require 'jwt'
require 'byebug'
require 'openssl/x509/spki'

# JWT class
class JWTHelper
  ALGORITHM = 'ES256'

  def self.decode(token)
    JWT.decode(token, key, false, algorithm: ALGORITHM).first
  end

  def self.key
    OpenSSL::PKey.read(File.read(File.join(Dir.pwd, 'keys', ENV['KEY']))).to_spki.to_key
  end
end
