# frozen_string_literal: true

# ADMIN_SEED_EMAIL/ADMIN_SEED_PASSWORD let each environment supply its own
# real credentials via its own env vars — the defaults below are only ever
# reached in local dev, where nobody sets them. Idempotent: find_or_initialize_by
# on email means re-running this always ends with one working admin login,
# never a duplicate.
admin_email = ENV.fetch("ADMIN_SEED_EMAIL", "admin@zoomora.com")
admin = AdminUser.find_or_initialize_by(email: admin_email)
admin.name = "Admin"
admin.password = ENV.fetch("ADMIN_SEED_PASSWORD", "password123")
admin.save!
puts "Seeded admin user (#{admin_email})."

# Starting content for the admin-managed homepage banner carousel (see
# Admin::PromotionalBannersController) — no photo attached here, same as
# products: seeds provide the text, real photos get uploaded through the
# admin panel afterward. Each banner shows on a plain dark background until
# then, never a broken image.
PROMOTIONAL_BANNERS = [
  { title: "Free Delivery & Assembly on Every Order", description: "From e-bikes to ATVs, we deliver across the UAE and set it up for you — no extra tools, no extra cost.", cta_label: "Shop All", cta_url: "/shop" },
  { title: "Buy Now, Pay Later Available", description: "Split your purchase into easy installments, available at checkout on every order.", cta_label: "Shop All", cta_url: "/shop" },
  { title: "12-Month Manufacturer Warranty", description: "Every vehicle we sell is backed by manufacturer warranty coverage, at no extra cost.", cta_label: "Shop All", cta_url: "/shop" },
  { title: "Free UAE-Wide Delivery & Installation", description: "Every order ships and is set up for you, anywhere in the Emirates, at no extra cost.", cta_label: "Start Shopping", cta_url: "/shop" }
].freeze

PROMOTIONAL_BANNERS.each_with_index do |attrs, index|
  banner = PromotionalBanner.find_or_initialize_by(title: attrs[:title])
  banner.assign_attributes(description: attrs[:description], cta_label: attrs[:cta_label], cta_url: attrs[:cta_url], position: index, active: true)
  banner.save!
end
puts "Seeded #{PromotionalBanner.count} promotional banners."

#
# Real Zoomora catalog, sourced from rafplay.com per direct client
# instruction (2026-08-05, relayed via WhatsApp): extract category by
# category, strip the "Megawheels"/"Megastar" brand names from product
# names, and price every item AED 50 below rafplay's own listed price.
# Prices are in AED, stored as price_cents (AED * 100) per
# DATABASE_GUIDELINES.md. Idempotent: safe to run more than once
# (find_or_create_by!/find_or_initialize_by on natural keys).
#
# The 1,165-product catalog itself lives in db/seed_data/rafplay_catalog.json
# (14 categories — every Zoomora category rafplay.com has an equivalent
# for), not inlined here as a literal — at ~1.9MB it would make this file
# unreadable and its diffs meaningless. "Repairs" has no rafplay equivalent
# (rafplay doesn't sell repair services), so its original 4 products stay
# defined directly below.
#
# Category display order matches the original nav (Ride-Ons through Play
# Sets) with the newer E-bikes/Cargo Scooters/Inflatables/Dirt Bikes/E-cars/
# Fuel/Repairs block appended after — both sets coexist per direct client
# feedback (2026-07-12), see the "feedback-navbar-order" memory.
RAFPLAY_CATALOG = JSON.parse(File.read(Rails.root.join("db/seed_data/rafplay_catalog.json")))

REPAIRS_CATEGORY = {
  "placeholder_key" => "atv",
  "description" => "Genuine spare parts and service packages to keep every Zoomora ride running, from battery swaps to full tune-ups.",
  "products" => [
    { "name" => "Full Tune-Up Service Package", "price_aed" => 299, "description" => "A scheduled inspection covering brakes, tyres, and electrical connections for any electric ride-on, scooter, or e-bike." },
    { "name" => "Replacement Battery Pack 12V", "price_aed" => 349, "description" => "A direct-fit replacement 12V battery pack compatible with most Zoomora ride-on vehicles." },
    { "name" => "Tyre & Tube Replacement Kit", "price_aed" => 149, "description" => "A puncture-repair kit with a spare inner tube and tyre levers, sized for scooters and bikes." },
    { "name" => "Brake Service & Adjustment", "price_aed" => 199, "description" => "Professional brake pad replacement and cable adjustment for scooters, e-bikes, and go-karts." }
  ]
}.freeze

CATALOG = RAFPLAY_CATALOG.merge("Repairs" => REPAIRS_CATEGORY)

# Real color variants, keyed by rafplay's own product id (see
# product_data["rafplay_id"] below) — only present for the 493 products that
# actually had more than one color on rafplay; single-color products have no
# entry here and stay a plain Product with no variants, same as "Repairs".
RAFPLAY_VARIANTS = JSON.parse(File.read(Rails.root.join("db/seed_data/rafplay_variants.json")))
variant_sku_sequence = ProductVariant.pluck(:sku).filter_map { |sku| sku[/\d+/]&.to_i }.max || 0

# Seeded from the highest existing SKU number (not just 0) so that re-seeding
# after reordering/restructuring CATALOG can never mint a SKU that collides
# with an existing product's already-assigned one — SKU assignment must not
# depend on a product's position in this file, only on it being genuinely new.
sku_sequence = Product.pluck(:sku).filter_map { |sku| sku[/\d+/]&.to_i }.max || 0
product_sequence = 0

CATALOG.each_with_index do |(category_name, category_data), category_index|
  category = Category.find_or_create_by!(name: category_name) do |c|
    c.description = category_data["description"]
    c.placeholder_key = category_data["placeholder_key"]
    c.position = category_index
  end
  # find_or_create_by!'s block only runs on creation, so an existing
  # category's position wouldn't otherwise track a reordered CATALOG — keep
  # nav order authoritative from this file even across re-seeding.
  category.update!(position: category_index) if category.position != category_index

  category_data["products"].each_with_index do |product_data, product_index|
    product_sequence += 1

    # Deterministic pseudo-random recency, independent of catalog/category
    # order, so "New Arrivals" (sorted by created_at) doesn't just surface
    # whichever category happens to be seeded last — it was doing exactly
    # that when every record simply got an auto-now timestamp in insertion order.
    days_ago = Digest::MD5.hexdigest(product_data["name"]).to_i(16) % 60

    product = Product.find_or_initialize_by(name: product_data["name"])
    if product.sku.blank?
      sku_sequence += 1
      product.sku = "ZMR-#{sku_sequence.to_s.rjust(5, '0')}"
    end
    product.assign_attributes(
      category: category,
      description: product_data["description"],
      price_cents: product_data["price_aed"] * 100,
      placeholder_key: category_data["placeholder_key"],
      position: product_index,
      specifications: product_data["specifications"] || {},
      # Every third product across the catalog is featured on the homepage;
      # keeps "Featured Picks" varied across categories rather than front-loaded.
      featured: (product_sequence % 3).zero?,
      # A different offset from "featured" so the Best Sellers rail isn't
      # just the same products under a second label.
      best_seller: (product_sequence % 4).zero?,
      created_at: days_ago.days.ago
    )
    product.save!

    # Real rafplay photos, attached once — never re-attach on a later
    # reseed (would otherwise duplicate every image on each `db:seed` run).
    if product.images.blank? && product_data["images"].present?
      product_data["images"].each do |relative_path|
        path = Rails.root.join(relative_path)
        next unless File.exist?(path)

        product.images.attach(io: File.open(path), filename: File.basename(path))
      end
    end

    # Real color variants (see RAFPLAY_VARIANTS above) — matched by
    # product + color, not sku, so re-seeding after rafplay's own sku data
    # shifts never creates duplicate variants for the same color.
    variants_data = RAFPLAY_VARIANTS[product_data["rafplay_id"].to_s]
    variants_data&.each do |variant_data|
      variant = ProductVariant.find_or_initialize_by(product: product, options: { "Color" => variant_data["color"] })
      if variant.sku.blank?
        # rafplay's own variant SKUs are unreliable (227 duplicate values
        # across unrelated products, e.g. "Land Rover" reused 4 times) — never
        # trust them, always mint our own to satisfy this app's uniqueness
        # constraint.
        variant_sku_sequence += 1
        variant.sku = "ZMR-V#{variant_sku_sequence.to_s.rjust(5, '0')}"
      end
      # Only set a price override when it differs from the product's own
      # price — otherwise every single-price product would get a pointless
      # override on every variant (ProductVariant#effective_price_cents
      # already falls back to the product's price when this is nil).
      variant_price_cents = variant_data["price_aed"] * 100
      variant.price_cents = variant_price_cents == product.price_cents ? nil : variant_price_cents
      variant.stock_quantity = variant_data["stock"] if variant_data["stock"].to_i.positive?
      variant.save!
    end
  end
end

puts "Seeded #{Category.count} categories and #{Product.count} products."

BLOG_POSTS = [
  {
    title: "5 Ways to Get Your Kids Off Screens This Weekend",
    cover_image_key: "scooter",
    excerpt: "Simple, low-effort ideas for turning a Friday afternoon into an actual family adventure — no extra planning required.",
    body: <<~TEXT.strip
      It's 4pm on a Friday, the heat has finally started to break, and every kid in the house is staring at a screen. Sound familiar? The good news is that getting outside doesn't need a big plan or a special occasion — it just needs the right gear already sitting in the garage.

      Start small. A twenty-minute scooter loop around the block or a quick splash in the pool before dinner is enough to reset a restless afternoon. The goal isn't a full day out — it's making outside the easy, default option instead of the effortful one.

      Rotate what's available. Kids get bored of the same scooter route or the same bike loop just like they get bored of anything else. Keeping two or three different activities within easy reach — a scooter, a bike, an inflatable raft in the pool — means there's always something that feels new enough to be worth putting the tablet down for.

      Make it a standing plan, not a one-off. "We ride bikes after school on Wednesdays" works better than waiting for motivation to strike. Once it's a habit, you stop having to convince anyone.
    TEXT
  },
  {
    title: "A Parent's Guide to ATV & Quad Bike Safety for Teens",
    cover_image_key: "atv",
    excerpt: "What to check before your teen's first ride, and the habits that keep every ride after it safe too.",
    body: <<~TEXT.strip
      An ATV or quad bike is often a teen's first taste of real off-road power, which makes it exciting — and it's exactly why a few basics matter before the first lap around the property.

      Start with the space, not the machine. Walk the riding area first for holes, fencing, or slopes steeper than they look from a distance, and agree on clear boundaries before the engine even starts. Most incidents come from unfamiliar terrain, not the vehicle itself.

      Use the adjustable speed limiter on youth and starter models, especially in the first few weeks. It's tempting to let a confident rider open it up right away, but keeping the ceiling lower at first builds the reflexes — braking, weight-shifting through turns — before the top speed does.

      Make helmets, gloves, and boots non-negotiable from ride one, even on the smallest-engine models. The gear habit matters more than the specific machine it started on, since it carries over to a dirt bike or a full-size ATV later.
    TEXT
  },
  {
    title: "ATV vs Dirt Bike vs Quad Bike: Which One Is Right for Your Teen?",
    cover_image_key: "dirtbike",
    excerpt: "Three very different riding experiences that often get lumped together — here's how to actually tell them apart.",
    body: <<~TEXT.strip
      "ATV," "quad," and "dirt bike" get used almost interchangeably in casual conversation, but they ride nothing alike, and picking the wrong one for your teen's experience level is the most common mistake we see.

      A quad bike (four wheels) is the most forgiving starting point. It's inherently stable at low speeds, doesn't require balance to stay upright at a stop, and most youth models come with an automatic transmission and an adjustable speed limiter — which is why we'd point a first-time rider here.

      A dirt bike (two wheels) demands balance and a manual clutch on most models, which means a real learning curve before it's actually fun rather than stressful. It rewards riders who already have some two-wheel experience, whether from a bicycle or a scooter, and want to step up to something with a throttle.

      Whichever you choose, match the engine size to the rider, not the other way around — a 50cc starter model and a 250cc adventure ATV are not the same category of decision, and neither is something to size up early "for growing room."
    TEXT
  },
  {
    title: "Getting Your Backyard Pool Ready for Summer",
    cover_image_key: "pool",
    excerpt: "A short pre-season checklist so the first hot weekend doesn't turn into a setup scramble.",
    body: <<~TEXT.strip
      The first real heatwave always seems to arrive faster than expected, and an above-ground pool that's been folded in storage since last year needs a bit of attention before anyone jumps in.

      Inspect the liner and frame before filling. Small punctures are far easier to patch on an empty pool than a full one, and a frame that's slightly bent from storage is worth straightening now rather than after it's under water pressure.

      Run the filter pump for a full cycle before the pool is in regular use, and check that the water is clear and the filter cartridge isn't still packed with dust from being in storage. A pump that's been sitting unused for months is worth testing on its own before anyone's relying on it.

      And if inflatables — kayaks, rafts, pool floats — are part of the plan, check the seams and valves while they're still dry. A slow leak is a five-minute fix with a patch kit and a much bigger annoyance mid-afternoon with a raft full of kids.
    TEXT
  },
  {
    title: "E-Bike Commuting 101: What Families Should Know Before Buying",
    cover_image_key: "bicycle",
    excerpt: "Battery range, motor power, and the questions worth asking before an e-bike replaces the school run.",
    body: <<~TEXT.strip
      E-bikes have gone from a niche purchase to a genuine second-car replacement for a lot of families, but the spec sheet can be confusing if you haven't shopped for one before.

      Range numbers are almost always best-case. A quoted 50 km range assumes flat ground, a lighter rider, and minimal use of the highest assist setting — in daily UAE heat with a loaded cargo rack, expect meaningfully less. Buy for your actual commute distance with room to spare, not the number on the box.

      Motor placement matters more than motor wattage. A mid-drive motor (built into the pedals) handles hills and cargo weight better than a hub motor of the same wattage, which is worth knowing if your route includes any real incline or you're planning to carry a child seat.

      Finally, check what's actually removable. A battery that locks in place for charging on the bike itself is far less convenient than a quick-release pack you can bring inside — a small detail that matters every single day, not just at purchase time.
    TEXT
  }
].freeze

BLOG_POSTS.each_with_index do |post_data, index|
  post = BlogPost.find_or_initialize_by(title: post_data[:title])
  post.assign_attributes(
    excerpt: post_data[:excerpt],
    body: post_data[:body],
    cover_image_key: post_data[:cover_image_key],
    # Staggered so the index reads as a real publishing history rather than
    # a single batch, newest (index 0) landing most recently.
    published_at: post.published_at || (index * 6 + 2).days.ago
  )
  post.save!
end

puts "Seeded #{BlogPost.count} blog posts."
