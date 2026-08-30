namespace :tabby do
  desc "One-time setup: register a real Tabby webhook endpoint pointed at the given URL, and print its signing secret"
  task :create_webhook, [ :url ] => :environment do |_, args|
    url = args[:url] || raise('Usage: rake "tabby:create_webhook[https://zoomora.com/tabby/webhooks]"')

    secret = SecureRandom.hex(32)
    response = Payments::Tabby.post("/api/v1/webhooks", {
      url: url,
      header: { title: "X-Tabby-Webhook-Secret", value: secret }
    }, headers: { "X-Merchant-Code" => ENV.fetch("TABBY_MERCHANT_CODE") })

    puts "Registered Tabby webhook: #{response['id']} -> #{url}"
    puts "Add this as TABBY_WEBHOOK_SECRET=#{secret} on the server this URL points at."
    puts "(This is a secret Rails generated, not something Tabby shows again — write it down now.)"
  end
end
