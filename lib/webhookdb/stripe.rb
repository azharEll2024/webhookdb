# frozen_string_literal: true

class Webhookdb::Stripe
  extend Webhookdb::MethodUtilities
  include Appydays::Configurable
  include Appydays::Loggable

  configurable(:stripe) do
    setting :api_key, "", key: "STRIPE_API_KEY"
    setting :webhook_secret, "", key: "STRIPE_WEBHOOK_SECRET"
  end

  def self.webhook_response(request)
    auth = request.env["HTTP_STRIPE_SIGNATURE"]

    return [401, {"Content-Type" => "application/json"}, '{"message": "missing hmac"}'] if auth.nil?

    request.body.rewind
    request_data = request.body.read

    begin
      Stripe::Webhook.construct_event(
        request_data, auth, self.webhook_secret,
      )
    rescue Stripe::SignatureVerificationError => e
      # Invalid signature
      self.logger.debug "stripe signature verification error: ", e
      return [401, {"Content-Type" => "application/json"}, '{"message": "invalid hmac"}']
    end

    return [200, {"Content-Type" => "application/json"}, '{"o":"k"}']
  end
end
