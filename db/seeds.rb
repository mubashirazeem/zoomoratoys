# frozen_string_literal: true

#
# Original Zoomora catalog copy for Milestone 1. Prices are in AED,
# stored as price_cents (AED * 100) per DATABASE_GUIDELINES.md. Idempotent:
# safe to run more than once (find_or_create_by! on the natural key).

CATALOG = {
  "Ebike" => {
    placeholder_key: "bicycle",
    description: "Electric-assist bikes for commuting, cargo hauling, and light trail riding, each with a removable battery and pedal-assist power modes.",
    products: [
      { name: "Harborfront Cargo Hauler", price_aed: 2_899, description: "A pedal-assist cargo e-bike with a front load bay rated for two children or grocery runs." },
      { name: "Summit E-Trail 27.5", price_aed: 3_499, description: "An electric-assist mountain e-bike with a removable battery and a 60 km assisted range." },
      { name: "Commuter Volt 350", price_aed: 2_999, description: "A 350W pedal-assist commuter e-bike with a 50 km range and integrated front and rear lights." },
      { name: "Foldaway City E-Bike", price_aed: 2_599, description: "A folding pedal-assist e-bike with a quick-release frame and a 35 km range, built for mixed transit-and-ride commutes." },
      { name: "Fat Tyre Trailblazer EB", price_aed: 4_299, description: "A fat-tyre electric bike with a 500W motor and front suspension, built for sand, gravel, and light trail riding." }
    ]
  },
  "Cargo Scooters" => {
    placeholder_key: "scooter",
    description: "Kick and seated electric scooters with cargo-ready decks and racks, spanning first rides for kids through commuter-range models for teens and adults.",
    products: [
      { name: "Kidling Foldable Scooter", price_aed: 899, description: "A lightweight foldable electric scooter for kids, with a 12 km/h speed cap and a low 15cm deck height." },
      { name: "Commuter Pro X1", price_aed: 3_299, description: "A commuter electric scooter with a 45 km range, dual disc brakes, and a front suspension fork." },
      { name: "Urban Glide Seated", price_aed: 2_699, description: "A seated electric scooter with a padded bench, front basket mount, and a 40 km range." },
      { name: "Trailhawk Off-Road Scooter", price_aed: 5_499, description: "An off-road electric scooter with knobby fat tires, dual motors, and hydraulic brakes for teens and adults." },
      { name: "Featherlight Teen Scooter", price_aed: 1_599, description: "A teen-sized electric scooter balancing a 25 km/h top speed with a folding frame for easy storage." },
      { name: "Longhaul Cargo Scooter", price_aed: 4_199, description: "A cargo-rated electric scooter with a rear basket and a reinforced deck for grocery runs." }
    ]
  },
  "Inflatables" => {
    placeholder_key: "pool",
    description: "Above-ground frame pools, kayaks, and inflatable rafts for backyard summers and lakeside trips.",
    products: [
      { name: "Steel Frame Family Pool 12ft", price_aed: 1_299, description: "A 12ft steel-frame above-ground pool with an included filter pump." },
      { name: "Backyard Splash Pool 8ft", price_aed: 549, description: "An 8ft quick-set frame pool that assembles in under 30 minutes." },
      { name: "Twin Explorer Kayak", price_aed: 899, description: "A two-person inflatable kayak with aluminum paddles and a foot pump included." },
      { name: "Lakeside Party Raft", price_aed: 449, description: "A four-person inflatable raft with cup holders and a tow rope attachment point." },
      { name: "Grand Rectangle Pool 16ft", price_aed: 2_699, description: "A 16ft rectangular frame pool with a reinforced liner and a sand-filter pump system." }
    ]
  },
  "Dirt Bikes" => {
    placeholder_key: "dirtbike",
    description: "Fuel and electric dirt bikes and pit bikes for teens and adults, from supervised starter models to manual-clutch trail builds.",
    products: [
      { name: "Ember Trail Dirt Bike 125", price_aed: 5_299, description: "A 125cc dirt bike with a manual clutch, built for older teens progressing off starter models." },
      { name: "Voltdash Electric Pit Bike", price_aed: 4_599, description: "An electric pit bike with a silent motor and three selectable power modes for supervised riders." },
      { name: "Scrambler Mini Dirt 50", price_aed: 2_299, description: "A 50cc automatic mini dirt bike sized for first-time young riders under close supervision." }
    ]
  },
  "ATVs & Quadbikes" => {
    placeholder_key: "atv",
    description: "Fuel and electric ATVs and quad bikes for teens and adults, from starter models to trail-rated builds.",
    products: [
      { name: "Ridgecrest 110 Youth ATV", price_aed: 3_999, description: "A 110cc youth ATV with an automatic transmission and an adjustable speed limiter." },
      { name: "Canyon Runner 200 Quad", price_aed: 7_499, description: "A 200cc automatic quad bike with a reverse gear and racked cargo mounts." },
      { name: "Outback 250 Adventure ATV", price_aed: 11_900, description: "A 250cc adult ATV with long-travel suspension and dual headlamps for adventure trail riding." }
    ]
  }
}.freeze

sku_sequence = 0

CATALOG.each_with_index do |(category_name, category_data), category_index|
  category = Category.find_or_create_by!(name: category_name) do |c|
    c.description = category_data[:description]
    c.placeholder_key = category_data[:placeholder_key]
    c.position = category_index
  end

  category_data[:products].each_with_index do |product_data, product_index|
    sku_sequence += 1

    # Deterministic pseudo-random recency, independent of catalog/category
    # order, so "New Arrivals" (sorted by created_at) doesn't just surface
    # whichever category happens to be seeded last — it was doing exactly
    # that when every record simply got an auto-now timestamp in insertion order.
    days_ago = Digest::MD5.hexdigest(product_data[:name]).to_i(16) % 60

    product = Product.find_or_initialize_by(name: product_data[:name])
    product.assign_attributes(
      category: category,
      description: product_data[:description],
      price_cents: product_data[:price_aed] * 100,
      sku: product.sku || "ZMR-#{sku_sequence.to_s.rjust(5, '0')}",
      placeholder_key: category_data[:placeholder_key],
      position: product_index,
      # Every third product across the catalog is featured on the homepage;
      # keeps "Featured Picks" varied across categories rather than front-loaded.
      featured: (sku_sequence % 3).zero?,
      # A different offset from "featured" so the Best Sellers rail isn't
      # just the same products under a second label.
      best_seller: (sku_sequence % 4).zero?,
      created_at: days_ago.days.ago
    )
    product.save!
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
