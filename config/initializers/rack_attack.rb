# frozen_string_literal: true

# Rate-limits abusive requests before they ever reach a controller — Devise's
# :lockable (see AdminUser/User) already stops brute-forcing *one* account,
# but does nothing about a single IP hammering many accounts, or a bot
# machine-gunning checkout to probe stock/coupon codes. This is the
# complementary, IP-level layer. Throttle state lives in Rails.cache (file
# store in production today — see config/environments/production.rb) which
# is enough for this app's current single-server deployment; move to a
# shared Redis cache store first if that ever changes.
class Rack::Attack
  # Broad safety net: no single IP should be making an extreme number of
  # requests across the whole site in a short window. Excludes Active
  # Storage/asset paths — product images are served through this same Rails
  # process (see config/environments/production.rb's `:local` storage
  # service), so a handful of page views from *one* IP can easily mean
  # hundreds of image requests. Counting those here would make this throttle
  # trip on ordinary browsing from any shared IP (office/campus/mobile
  # carrier NAT), not just abuse. Also excludes the Stripe webhook path —
  # every request there arrives from Stripe's own infrastructure (a small,
  # shared pool of IPs shared across every Stripe merchant), is already
  # authenticated by its cryptographic signature, and legitimate retry/burst
  # traffic from Stripe should never be rate-limited away.
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?("/rails/active_storage", "/assets", "/stripe/webhooks")
  end

  # Admin sign-in — by IP (stops one machine hammering any account) and by
  # the submitted email (stops a distributed attack spread across many IPs
  # at one account), same dual-key pattern Rack::Attack's own docs recommend.
  throttle("admin_logins/ip", limit: 10, period: 20.seconds) do |req|
    req.ip if req.path == "/admin_users/sign_in" && req.post?
  end

  throttle("admin_logins/email", limit: 5, period: 20.seconds) do |req|
    if req.path == "/admin_users/sign_in" && req.post?
      req.params.dig("admin_user", "email").to_s.downcase.presence
    end
  end

  # Customer sign-in — same dual-key pattern.
  throttle("user_logins/ip", limit: 10, period: 20.seconds) do |req|
    req.ip if req.path == "/users/sign_in" && req.post?
  end

  throttle("user_logins/email", limit: 5, period: 20.seconds) do |req|
    if req.path == "/users/sign_in" && req.post?
      req.params.dig("user", "email").to_s.downcase.presence
    end
  end

  # Checkout submission — stops a bot from rapid-firing order creation to
  # probe stock levels or brute-force coupon codes.
  throttle("checkout/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path == "/checkout" && req.post?
  end

  # Branded response instead of rack-attack's plain-text default — this
  # fires before any Rails controller/view runs, so it can't reuse the real
  # layout; a small self-contained HTML page matching the brand instead of
  # a bare "Retry later" is the closest this layer can get to it.
  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"]
    retry_after = match_data[:period] - (match_data[:epoch_time] % match_data[:period])

    body = <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="utf-8">
        <title>Too Many Requests — Zoomora</title>
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <style>
          * { box-sizing: border-box; }
          html, body { height: 100%; margin: 0; background: #FFFFFF; color: #0A0A0B; font-family: Arial, Helvetica, sans-serif; }
          .wrap { min-height: 100%; display: flex; align-items: center; justify-content: center; padding: 24px; }
          .card { max-width: 480px; width: 100%; text-align: center; }
          .brand { height: 48px; width: auto; margin-bottom: 28px; }
          .code { font-size: 15px; font-weight: 600; letter-spacing: 0.08em; text-transform: uppercase; color: #7E8189; margin: 0 0 10px; }
          h1 { font-size: 28px; font-weight: 700; line-height: 1.25; margin: 0 0 12px; color: #0A0A0B; }
          p.lead { font-size: 14px; line-height: 1.6; color: #5B5E66; margin: 0; }
        </style>
      </head>
      <body>
        <div class="wrap">
          <div class="card">
            <img class="brand" src="/images/logo-transparent.png" alt="Zoomora">
            <p class="code">Error 429</p>
            <h1>Too many requests.</h1>
            <p class="lead">Please slow down a little and try again in about #{retry_after} seconds.</p>
          </div>
        </div>
      </body>
      </html>
    HTML

    [ 429, { "content-type" => "text/html", "retry-after" => retry_after.to_s }, [ body ] ]
  end
end
