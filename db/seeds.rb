# frozen_string_literal: true

#
# Original Zoomora catalog copy for Milestone 1. Prices are in AED,
# stored as price_cents (AED * 100) per DATABASE_GUIDELINES.md. Idempotent:
# safe to run more than once (find_or_create_by! on the natural key).

# Category display order matches the original nav (Ride-Ons through Play
# Sets) with the newer E-bikes/Cargo Scooters/Inflatables/Dirt Bikes block
# appended after — both sets coexist per direct client feedback (2026-07-12),
# see the "feedback-navbar-order" memory. Several pairs intentionally share a
# placeholder_key/photo (no distinct photography exists yet for the newer
# names) but are genuinely different product sets, not duplicates:
# Scooters (regular) vs Cargo Scooters (cargo-rated), Bicycles (pedal) vs
# E-bikes (electric-assist), Pools (frame pools) vs Inflatables (kayaks/rafts).
CATALOG = {
  "Ride-Ons" => {
    placeholder_key: "rideon",
    description: "Battery-powered ride-on cars, jeeps, and buggies for toddlers and young kids, each with a parental speed override.",
    products: [
      { name: "Trailblazer Junior 4x4", price_aed: 1_299, description: "A 12V ride-on 4x4 with working headlights, a two-speed motor, and a padded roll bar for young off-roaders." },
      { name: "Coastline Cruiser Convertible", price_aed: 1_499, description: "A 12V convertible ride-on with a removable parent handle, working horn, and a smooth-start motor for first-time drivers." },
      { name: "Dune Racer Buggy", price_aed: 1_799, description: "A dual-motor 12V ride-on buggy with oversized traction tyres and a top speed capped for young drivers." },
      { name: "Little Cub Off-Roader", price_aed: 999, description: "An entry-level 6V ride-on with a single-speed motor and a wide stable base, built for a child's very first ride." }
    ]
  },
  "Scooters" => {
    placeholder_key: "scooter",
    description: "Kick and seated electric scooters spanning first rides for kids through commuter-range models for teens and adults.",
    products: [
      { name: "Kidling Foldable Scooter", price_aed: 899, description: "A lightweight foldable electric scooter for kids, with a 12 km/h speed cap and a low 15cm deck height." },
      { name: "Commuter Pro X1", price_aed: 3_299, description: "A commuter electric scooter with a 45 km range, dual disc brakes, and a front suspension fork." },
      { name: "Urban Glide Seated", price_aed: 2_699, description: "A seated electric scooter with a padded bench, front basket mount, and a 40 km range." },
      { name: "Trailhawk Off-Road Scooter", price_aed: 5_499, description: "An off-road electric scooter with knobby fat tires, dual motors, and hydraulic brakes for teens and adults." },
      { name: "Featherlight Teen Scooter", price_aed: 1_599, description: "A teen-sized electric scooter balancing a 25 km/h top speed with a folding frame for easy storage." }
    ]
  },
  "Golf Carts" => {
    placeholder_key: "golf_cart",
    description: "Electric golf carts and neighborhood buggies for family trips, errands, and community cruising, from two-seat runabouts to six-seat limousines.",
    products: [
      { name: "Fairway Four Classic", price_aed: 24_999, description: "A four-seat electric golf cart with a street-legal light kit and a 45 km range per charge." },
      { name: "Estate Two Seater", price_aed: 19_999, description: "A compact two-seat electric golf cart built for community streets, errands, and short family trips." },
      { name: "Resort Six Limo Cart", price_aed: 34_900, description: "A six-seat limousine-style electric golf cart with rear-facing bench seating for larger family outings." }
    ]
  },
  "Bicycles" => {
    placeholder_key: "bicycle",
    description: "Pedal bikes for every age, from a first ride with training wheels to a multi-speed trail bike.",
    products: [
      { name: "Trailridge Kids Bike 16-Inch", price_aed: 599, description: "A 16-inch pedal bike with training wheels and a coaster brake, sized for a child's first ride." },
      { name: "Meadowbrook Cruiser", price_aed: 1_199, description: "A single-speed cruiser bike with a step-through frame and a padded saddle, built for easy neighborhood rides." },
      { name: "Ridgeline Trail 21-Speed", price_aed: 1_899, description: "A 21-speed mountain bike with front suspension and disc brakes, built for mixed pavement and light trail riding." },
      { name: "Tandem Family Cruiser", price_aed: 2_499, description: "A two-seat tandem bicycle with a shared drivetrain, built for parent-and-child rides along the boardwalk." }
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
  },
  "Trampolines" => {
    placeholder_key: "trampoline",
    description: "Backyard trampolines with full safety enclosures, sized from a child's first bounce to a family-size ring.",
    products: [
      { name: "Backyard Bounce 8ft", price_aed: 899, description: "An 8ft trampoline with a full safety enclosure net and a padded spring cover." },
      { name: "Skyline Bounce 10ft", price_aed: 1_299, description: "A 10ft trampoline with galvanized steel legs and a UV-resistant enclosure net built for daily UAE sun." },
      { name: "Junior Jump 6ft", price_aed: 549, description: "A compact 6ft trampoline with a low bounce height and enclosure net, sized for younger kids." }
    ]
  },
  "Pools" => {
    placeholder_key: "pool",
    description: "Above-ground frame pools for backyard summers, from a quick-set starter size to a family-size rectangle.",
    products: [
      { name: "Steel Frame Family Pool 12ft", price_aed: 1_299, description: "A 12ft steel-frame above-ground pool with an included filter pump." },
      { name: "Backyard Splash Pool 8ft", price_aed: 549, description: "An 8ft quick-set frame pool that assembles in under 30 minutes." },
      { name: "Grand Rectangle Pool 16ft", price_aed: 2_699, description: "A 16ft rectangular frame pool with a reinforced liner and a sand-filter pump system." }
    ]
  },
  "Play Sets" => {
    placeholder_key: "playset",
    description: "Climbing frames, playhouses, and swing sets built to handle daily backyard play for years, not just a season.",
    products: [
      { name: "Fort Horizon Climbing Frame", price_aed: 2_199, description: "A wooden climbing frame with a double slide, a rope climb, and a covered lookout tower." },
      { name: "Backyard Base Camp Playhouse", price_aed: 1_699, description: "A wooden playhouse with a working door, shuttered windows, and a small front porch." },
      { name: "Summit Swing & Slide Set", price_aed: 1_499, description: "A steel-frame swing set with two swings, a slide, and a climbing ladder." }
    ]
  },
  "E-bikes" => {
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
    description: "Cargo-rated electric scooters with reinforced decks and racks, built for grocery runs and neighborhood errands.",
    products: [
      { name: "Longhaul Cargo Scooter", price_aed: 4_199, description: "A cargo-rated electric scooter with a rear basket and a reinforced deck for grocery runs." },
      { name: "Errand Runner Cargo Scooter", price_aed: 2_199, description: "A compact cargo scooter with a front basket and a low step-through frame, sized for quick neighborhood errands." },
      { name: "Heavy Hauler XL Scooter", price_aed: 5_899, description: "A dual-motor cargo scooter with a reinforced rear rack rated for higher loads and longer routes." }
    ]
  },
  "Inflatables" => {
    placeholder_key: "pool",
    description: "Kayaks, rafts, and inflatable pool floats for lakeside trips and backyard summers.",
    products: [
      { name: "Twin Explorer Kayak", price_aed: 899, description: "A two-person inflatable kayak with aluminum paddles and a foot pump included." },
      { name: "Lakeside Party Raft", price_aed: 449, description: "A four-person inflatable raft with cup holders and a tow rope attachment point." },
      { name: "Sundeck Lounge Float", price_aed: 249, description: "An inflatable pool lounger with built-in cup holders and a mesh backrest, sized for one adult." }
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
  # Added per direct client feedback (2026-07-12): E-cars, Fuel, and Repairs
  # as three more navbar categories, same additive pattern as the earlier
  # Ebike/Cargo Scooters/Inflatables/Dirt Bikes block. No distinct
  # photography exists yet for any of the three, so each shares an existing
  # placeholder_key/photo (E-cars↔rideon, Fuel↔dirtbike are reasonable visual
  # matches; Repairs↔atv is the weakest match of the three and should be the
  # first swapped out once real photography exists — see
  # DEVELOPMENT_PROGRESS.md tracked follow-ups).
  "E-cars" => {
    placeholder_key: "rideon",
    description: "Larger-scale electric ride-on cars for bigger kids and teens, styled like real vehicles with working doors and lights — a step up from our toddler ride-ons.",
    products: [
      { name: "Metro Roadster Kids Car", price_aed: 2_199, description: "A 24V two-seater electric ride-on car with working doors, LED headlights, and a parent remote override." },
      { name: "Highline GT Junior", price_aed: 2_799, description: "A 24V single-seat sports-style electric car with rubber traction tyres and a real-feel dashboard." },
      { name: "Family Cruiser Two-Seater", price_aed: 3_299, description: "A 24V two-seat electric car with a speed-capped motor, working suspension, and a built-in Bluetooth speaker." }
    ]
  },
  "Fuel" => {
    placeholder_key: "dirtbike",
    description: "Petrol-powered mini bikes and go-karts for older teens who've outgrown electric starter models, with automatic and manual-clutch options.",
    products: [
      { name: "Trailmaster 110 Petrol Mini Bike", price_aed: 4_599, description: "An automatic 110cc petrol mini dirt bike with a rear brake and a governor-limited top speed for supervised trail riding." },
      { name: "Ridgeline 160 Go-Kart", price_aed: 6_999, description: "A petrol-powered off-road go-kart with a roll cage and a five-point safety harness." },
      { name: "Backroad 125 Pit Bike", price_aed: 5_299, description: "A manual-clutch 125cc petrol pit bike for teens progressing off automatic models." }
    ]
  },
  "Repairs" => {
    placeholder_key: "atv",
    description: "Genuine spare parts and service packages to keep every Zoomora ride running, from battery swaps to full tune-ups.",
    products: [
      { name: "Full Tune-Up Service Package", price_aed: 299, description: "A scheduled inspection covering brakes, tyres, and electrical connections for any electric ride-on, scooter, or e-bike." },
      { name: "Replacement Battery Pack 12V", price_aed: 349, description: "A direct-fit replacement 12V battery pack compatible with most Zoomora ride-on vehicles." },
      { name: "Tyre & Tube Replacement Kit", price_aed: 149, description: "A puncture-repair kit with a spare inner tube and tyre levers, sized for scooters and bikes." },
      { name: "Brake Service & Adjustment", price_aed: 199, description: "Professional brake pad replacement and cable adjustment for scooters, e-bikes, and go-karts." }
    ]
  }
}.freeze

# Seeded from the highest existing SKU number (not just 0) so that re-seeding
# after reordering/restructuring CATALOG can never mint a SKU that collides
# with an existing product's already-assigned one — SKU assignment must not
# depend on a product's position in this file, only on it being genuinely new.
sku_sequence = Product.pluck(:sku).filter_map { |sku| sku[/\d+/]&.to_i }.max || 0
product_sequence = 0

CATALOG.each_with_index do |(category_name, category_data), category_index|
  category = Category.find_or_create_by!(name: category_name) do |c|
    c.description = category_data[:description]
    c.placeholder_key = category_data[:placeholder_key]
    c.position = category_index
  end
  # find_or_create_by!'s block only runs on creation, so an existing
  # category's position wouldn't otherwise track a reordered CATALOG — keep
  # nav order authoritative from this file even across re-seeding.
  category.update!(position: category_index) if category.position != category_index

  category_data[:products].each_with_index do |product_data, product_index|
    product_sequence += 1

    # Deterministic pseudo-random recency, independent of catalog/category
    # order, so "New Arrivals" (sorted by created_at) doesn't just surface
    # whichever category happens to be seeded last — it was doing exactly
    # that when every record simply got an auto-now timestamp in insertion order.
    days_ago = Digest::MD5.hexdigest(product_data[:name]).to_i(16) % 60

    product = Product.find_or_initialize_by(name: product_data[:name])
    if product.sku.blank?
      sku_sequence += 1
      product.sku = "ZMR-#{sku_sequence.to_s.rjust(5, '0')}"
    end
    product.assign_attributes(
      category: category,
      description: product_data[:description],
      price_cents: product_data[:price_aed] * 100,
      placeholder_key: category_data[:placeholder_key],
      position: product_index,
      # Every third product across the catalog is featured on the homepage;
      # keeps "Featured Picks" varied across categories rather than front-loaded.
      featured: (product_sequence % 3).zero?,
      # A different offset from "featured" so the Best Sellers rail isn't
      # just the same products under a second label.
      best_seller: (product_sequence % 4).zero?,
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
