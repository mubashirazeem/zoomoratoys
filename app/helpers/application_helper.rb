module ApplicationHelper
  # See CurrenciesController and ExchangeRate — the only two currencies a
  # visitor can pick to *display* prices in. The actual charge is always
  # AED (Payments::StripeCheckoutSessionBuilder is hardcoded to "aed" and
  # stays that way); nothing here ever touches money that's actually
  # collected, only what a shopping page shows before checkout.
  DISPLAY_CURRENCIES = %w[AED USD].freeze

  # The visitor's chosen display currency — a plain (not signed) cookie,
  # since tampering with it can only change what's shown, never what's
  # charged. Defaults to AED for anyone who's never picked one.
  def display_currency
    cookies[:currency].presence_in(DISPLAY_CURRENCIES) || "AED"
  end

  # Renders an integer AED-cent amount (see DATABASE_GUIDELINES.md) as "AED
  # 1,234" — this catalog's price points have no fractional AED, so there's
  # no decimal handling to worry about. The single formatter for currency
  # anywhere in the app; components reach it via `helpers.format_aed`.
  #
  # This always renders the real AED amount regardless of
  # display_currency — used for anything that's a record of what was
  # actually charged (admin, invoices, packing slip, order confirmation,
  # order history, every email) or a VAT figure tied to that real amount.
  # For a pre-purchase shopping page, use format_price instead.
  def format_aed(cents)
    "AED #{number_with_thousands(cents / 100)}"
  end

  # Same amount as format_aed, converted to the visitor's chosen display
  # currency (ExchangeRate.current_usd_per_aed backs the AED->USD rate).
  # For shopping-flow pages only (product cards, cart, checkout summary) —
  # see format_aed's own comment for where to use that one instead. Unlike
  # format_aed, this keeps two decimal places once converted: AED price
  # points land on whole dirhams, but their USD equivalent routinely
  # doesn't (AED 600 -> $163.38, not $163).
  def format_price(cents)
    return format_aed(cents) if display_currency == "AED"

    usd_cents = (cents * ExchangeRate.current_usd_per_aed).round
    whole, sub_units = usd_cents.divmod(100)
    "$#{number_with_thousands(whole)}.#{sub_units.to_s.rjust(2, '0')} USD"
  end

  # Same currency, but keeps fils (the 2 decimal places format_aed
  # deliberately drops) — needed for the invoice's VAT breakdown, since
  # backing 5% out of a whole-dirham total routinely lands on a fractional
  # amount (e.g. AED 215.00 -> AED 204.76 excl. VAT + AED 10.24 VAT).
  def format_aed_precise(cents)
    whole, fils = cents.divmod(100)
    "AED #{number_with_thousands(whole)}.#{fils.to_s.rjust(2, '0')}"
  end

  # Caption shown under a Total anywhere a price is displayed — prices are
  # VAT-inclusive already (see Order::VAT_RATE), so this backs the 5%
  # amount out of the same total_cents already on screen rather than
  # changing what's charged.
  def vat_inclusive_note(total_cents)
    "Includes VAT (5%): #{format_aed_precise(Order.vat_portion_of(total_cents))}"
  end

  # Hand-rolled rather than ActionView's number_with_delimiter: that helper
  # isn't reliably mixed into a ViewComponent's `helpers` proxy, while a
  # plain custom ApplicationHelper method (this one) is.
  def number_with_thousands(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse
  end

  # content_tag would normally HTML-escape the JSON body, corrupting it (a
  # JSON `"` becomes `&quot;`) — so this marks it html_safe instead. That's
  # safe here because Rails' own to_json already neutralizes a data value
  # like a product description containing a literal "</script>" before this
  # method ever sees it: config.active_support.escape_html_entities_in_json
  # (Rails' own default, true) makes to_json render every "<" as a plain
  # backslash-u escape sequence instead, so no literal "</" ever reaches the
  # .gsub below. The .gsub stays anyway as a
  # backstop against that one global setting ever being flipped off for an
  # unrelated reason elsewhere in the app — cheap insurance, verified with
  # `ActiveSupport.escape_html_entities_in_json` and a real to_json call.
  def json_ld_script_tag(data)
    content_tag(:script, data.to_json.gsub("</", '<\/').html_safe, type: "application/ld+json")
  end

  # display_photo returns either a plain asset-path String (no images
  # uploaded yet — see Product#display_photo) or an ActiveStorage variant
  # object, and each needs a different Rails helper to become an absolute
  # URL.
  def product_og_image_url(product)
    photo = product.display_photo(resize_to_limit: [ 1200, 630 ])
    photo.is_a?(String) ? image_url(photo) : url_for(photo)
  end

  def product_json_ld(product)
    data = {
      "@context": "https://schema.org",
      "@type": "Product",
      name: product.name,
      image: [ product_og_image_url(product) ],
      description: product.description,
      sku: product.sku,
      brand: { "@type": "Brand", name: "Zoomora" },
      offers: {
        "@type": "Offer",
        priceCurrency: "AED",
        price: format("%.2f", product.price_cents / 100.0),
        availability: product_schema_availability(product),
        url: product_url(product)
      }
    }

    if product.reviews.count.positive?
      data[:aggregateRating] = {
        "@type": "AggregateRating",
        # Product#average_rating is a BigDecimal (from an AVG query); Rails'
        # BigDecimal#as_json renders it as a quoted string ("4.0") to avoid
        # float precision loss, but schema.org's ratingValue must be a real
        # JSON number — #to_f gives up that (irrelevant here) precision
        # guard in exchange for the correct JSON type.
        ratingValue: product.average_rating.to_f,
        reviewCount: product.reviews.count
      }
    end

    data
  end

  # stock_status alone is unreliable for a product with variants (parent
  # stock is irrelevant once ProductVariant-level stock takes over — see
  # Product#out_of_stock?), so this defers to that same method rather than
  # reading stock_status directly.
  def product_schema_availability(product)
    return "https://schema.org/OutOfStock" if product.out_of_stock?
    return "https://schema.org/PreOrder" if !product.has_variants? && product.preorder?

    "https://schema.org/InStock"
  end

  def breadcrumb_json_ld(items)
    {
      "@context": "https://schema.org",
      "@type": "BreadcrumbList",
      itemListElement: items.each_with_index.map { |item, index|
        { "@type": "ListItem", position: index + 1, name: item[:name], item: item[:url] }
      }
    }
  end
end
