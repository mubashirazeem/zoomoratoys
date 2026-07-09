# frozen_string_literal: true

#
# Original Zoomora Toys catalog copy for Milestone 1. Prices are in AED,
# stored as price_cents (AED * 100) per DATABASE_GUIDELINES.md. Idempotent:
# safe to run more than once (find_or_create_by! on the natural key).

CATALOG = {
  "Ride-On Vehicles" => {
    placeholder_key: "rideon",
    description: "Battery-powered cars, jeeps, and buggies built for small drivers, with parental remote override on every model.",
    products: [
      { name: "Trailblazer Junior 4x4", price_aed: 1_299, description: "A 12V ride-on 4x4 with working headlights, a two-speed motor, and a padded roll bar for young off-roaders." },
      { name: "Coastline Cruiser Convertible", price_aed: 1_899, description: "A stylish 12V convertible ride-on with a soft-touch steering wheel and built-in music player." },
      { name: "Dune Racer Buggy", price_aed: 1_599, description: "A rugged 12V buggy with oversized tires and suspension tuned for backyard trails." },
      { name: "Baby's First Cruiser", price_aed: 549, description: "A gentle 6V ride-on for toddlers, with a parent push-handle and a top speed capped for safety." },
      { name: "Twin Seater Family Wagon", price_aed: 2_199, description: "A two-seat 24V ride-on built for siblings to share, with independent seatbelts and dual-zone lighting." },
      { name: "Metro Police Patrol Jeep", price_aed: 1_349, description: "A themed 12V patrol jeep with a working siren, roof lights, and a radio-style dashboard toy." },
      { name: "Alpine Explorer Mini Jeep", price_aed: 1_749, description: "A 12V mini jeep with a working trunk, roof rack, and a canopy for shaded rides." },
      { name: "Thunderbolt Pit Racer", price_aed: 1_449, description: "A racing-styled 12V ride-on with racing decals, a sport steering wheel, and a low center of gravity." }
    ]
  },
  "Electric Scooters" => {
    placeholder_key: "scooter",
    description: "Kick and seated electric scooters spanning first rides for kids through commuter-range models for teens and adults.",
    products: [
      { name: "Kidling Foldable Scooter", price_aed: 899, description: "A lightweight foldable electric scooter for kids, with a 12 km/h speed cap and a low 15cm deck height." },
      { name: "Commuter Pro X1", price_aed: 3_299, description: "A commuter electric scooter with a 45 km range, dual disc brakes, and a front suspension fork." },
      { name: "Urban Glide Seated", price_aed: 2_699, description: "A seated electric scooter with a padded bench, front basket mount, and a 40 km range." },
      { name: "Trailhawk Off-Road Scooter", price_aed: 5_499, description: "An off-road electric scooter with knobby fat tires, dual motors, and hydraulic brakes for teens and adults." },
      { name: "Featherlight Teen Scooter", price_aed: 1_599, description: "A teen-sized electric scooter balancing a 25 km/h top speed with a folding frame for easy storage." },
      { name: "Longhaul Cargo Scooter", price_aed: 4_199, description: "A cargo-rated electric scooter with a rear basket and a reinforced deck for grocery runs." }
    ]
  },
  "Electric Golf Carts" => {
    placeholder_key: "golf_cart",
    description: "Street-legal-style electric golf carts and buggies for family sightseeing, resorts, and large properties.",
    products: [
      { name: "Fairway Four Classic", price_aed: 24_999, description: "A 4-seat electric golf cart with a lithium battery pack, LED lighting, and a fold-flat rear bench." },
      { name: "Sundowner Six Seater", price_aed: 34_500, description: "A 6-seat electric golf cart designed for resort shuttling, with a canopy roof and USB charging ports." },
      { name: "Ridgeline Lifted Buggy", price_aed: 29_900, description: "A lifted 4-seat electric buggy with off-road suspension and all-terrain tires." },
      { name: "Estate Two Seater", price_aed: 19_999, description: "A compact 2-seat electric golf cart sized for tighter driveways and garden paths." },
      { name: "Marina Cargo Hauler", price_aed: 27_500, description: "A 2-seat electric golf cart with a rear cargo bed, built for property maintenance runs." }
    ]
  },
  "Bicycles & Cargo Bikes" => {
    placeholder_key: "bicycle",
    description: "Pedal and electric-assist bicycles for kids learning to ride through adult commuters and cargo hauling.",
    products: [
      { name: "First Pedal 16-Inch", price_aed: 449, description: "A 16-inch kids' bicycle with training wheels and a low step-through frame for confident first rides." },
      { name: "Trailblazer Mountain 26", price_aed: 1_299, description: "A 26-inch mountain bike with a 21-speed drivetrain and front suspension for light trail riding." },
      { name: "Cityline Folding Commuter", price_aed: 1_599, description: "A folding commuter bicycle with a lightweight aluminum frame, built for mixed transit-and-ride commutes." },
      { name: "Harborfront Cargo Hauler", price_aed: 2_899, description: "A pedal-assist cargo bike with a front load bay rated for two children or grocery runs." },
      { name: "Summit E-Trail 27.5", price_aed: 3_499, description: "An electric-assist mountain bike with a removable battery and a 60 km assisted range." },
      { name: "Boardwalk Cruiser", price_aed: 899, description: "A single-speed beach cruiser with a wide comfort saddle and swept-back handlebars." }
    ]
  },
  "ATVs & Dirt Bikes" => {
    placeholder_key: "atv",
    description: "Fuel and electric ATVs, quad bikes, and dirt bikes for teens and adults, from starter models to trail-rated builds.",
    products: [
      { name: "Ridgecrest 110 Youth ATV", price_aed: 3_999, description: "A 110cc youth ATV with an automatic transmission and an adjustable speed limiter." },
      { name: "Canyon Runner 200 Quad", price_aed: 7_499, description: "A 200cc automatic quad bike with a reverse gear and racked cargo mounts." },
      { name: "Ember Trail Dirt Bike 125", price_aed: 5_299, description: "A 125cc dirt bike with a manual clutch, built for older teens progressing off starter models." },
      { name: "Voltdash Electric Pit Bike", price_aed: 4_599, description: "An electric pit bike with a silent motor and three selectable power modes for supervised riders." },
      { name: "Outback 250 Adventure ATV", price_aed: 11_900, description: "A 250cc adult ATV with long-travel suspension and dual headlamps for adventure trail riding." },
      { name: "Scrambler Mini Dirt 50", price_aed: 2_299, description: "A 50cc automatic mini dirt bike sized for first-time young riders under close supervision." }
    ]
  },
  "Trampolines" => {
    placeholder_key: "trampoline",
    description: "Backyard trampolines with enclosure nets, sized for small gardens through full family back yards.",
    products: [
      { name: "Backyard Bounce 8ft", price_aed: 899, description: "An 8ft round trampoline with a padded frame cover and a full-height safety enclosure net." },
      { name: "Skyline Bounce 12ft", price_aed: 1_499, description: "A 12ft round trampoline rated for multiple jumpers, with galvanized-steel legs." },
      { name: "Family Arena 14ft", price_aed: 1_899, description: "A 14ft trampoline with a reinforced jumping mat and a two-door zippered enclosure." },
      { name: "Compact Hopper 6ft", price_aed: 549, description: "A 6ft junior trampoline sized for small gardens and younger jumpers." },
      { name: "Rectangle Pro Bounce", price_aed: 2_299, description: "A rectangular trampoline with sport-grade spring tension, styled after competition frames." }
    ]
  },
  "Pools & Inflatables" => {
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
  "Play Sets" => {
    placeholder_key: "playset",
    description: "Climbing frames, playhouses, and activity sets for garden play at every age.",
    products: [
      { name: "Fort Horizon Climbing Frame", price_aed: 2_199, description: "A wooden climbing frame with a slide, rope ladder, and a covered lookout deck." },
      { name: "Meadow Playhouse Cottage", price_aed: 1_699, description: "A garden playhouse with working shutters, a Dutch door, and a flower-box ledge." },
      { name: "Ball Pit Activity Dome", price_aed: 649, description: "A pop-up activity dome with a tunnel entrance, sold with 100 play balls included." },
      { name: "Adventure Swing & Slide Set", price_aed: 1_899, description: "A combination swing set with a double swing bay, a wave slide, and a climbing wall panel." },
      { name: "Sandcastle Builder Pit", price_aed: 549, description: "A covered sandpit with a bench-seat lid and a matched set of building tools." }
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
