// test_engine.js — Unit Tests for DeTrack URL Cleaner & QRCode Generator
const assert = require("assert");
const Engine = require("../Engine.js");
const QRCode = require("../QRCode.js");

console.log("🧪 Running DeTrack Test Suite...\n");

let passed = 0;
let total = 0;

function test(name, fn) {
  total++;
  try {
    fn();
    console.log(`  ✓ ${name}`);
    passed++;
  } catch (err) {
    console.error(`  ✗ ${name}`);
    console.error(`    ${err.message}`);
  }
}

// 1. Google Analytics / UTM parameters
test("Strips standard Google UTM parameters", () => {
  const dirty = "https://example.com/page?utm_source=newsletter&utm_medium=email&utm_campaign=summer_sale&utm_term=shoes&utm_content=logolink&real_param=123";
  const res = Engine.cleanUrl(dirty);
  assert.strictEqual(res.isValid, true);
  assert.strictEqual(res.cleanedUrl, "https://example.com/page?real_param=123");
  assert.strictEqual(res.trackersCount, 5);
  assert(res.trackersRemoved.includes("utm_source"));
  assert(res.trackersRemoved.includes("utm_medium"));
  assert(res.trackersRemoved.includes("utm_campaign"));
});

// 2. Facebook / Meta
test("Strips Facebook fbclid tracker", () => {
  const dirty = "https://example.com/article?fbclid=IwAR2V8d43_XYZ123456789&id=42";
  const res = Engine.cleanUrl(dirty);
  assert.strictEqual(res.isValid, true);
  assert.strictEqual(res.cleanedUrl, "https://example.com/article?id=42");
  assert(res.trackersRemoved.includes("fbclid"));
});

// 3. YouTube share trackers
test("Strips YouTube share trackers (si, feature, pp) while preserving video ID and timestamp", () => {
  const dirty = "https://www.youtube.com/watch?v=dQw4w9WgXcQ&si=AbCdEfGhIjKl&feature=shared&t=42";
  const res = Engine.cleanUrl(dirty);
  assert.strictEqual(res.isValid, true);
  assert.strictEqual(res.cleanedUrl, "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=42");
  assert(res.trackersRemoved.includes("si"));
  assert(res.trackersRemoved.includes("feature"));
});

// 4. youtu.be shortlinks
test("Strips youtu.be tracking parameters", () => {
  const dirty = "https://youtu.be/dQw4w9WgXcQ?si=abcdefg1234567";
  const res = Engine.cleanUrl(dirty);
  assert.strictEqual(res.isValid, true);
  assert.strictEqual(res.cleanedUrl, "https://youtu.be/dQw4w9WgXcQ");
  assert(res.trackersRemoved.includes("si"));
});

// 5. Twitter / X tracking parameters
test("Strips Twitter / X tracking parameters (s, t, twclid)", () => {
  const dirty = "https://x.com/username/status/1234567890123456789?s=20&t=abcdefg&twclid=98765";
  const res = Engine.cleanUrl(dirty);
  assert.strictEqual(res.isValid, true);
  assert.strictEqual(res.cleanedUrl, "https://x.com/username/status/1234567890123456789");
  assert(res.trackersRemoved.includes("s"));
  assert(res.trackersRemoved.includes("t"));
  assert(res.trackersRemoved.includes("twclid"));
});

// 6. Instagram igshid
test("Strips Instagram tracking parameters (igsh, igshid)", () => {
  const dirty = "https://www.instagram.com/p/C3XYZ123/?igsh=MzRlODBiNWFlZA==";
  const res = Engine.cleanUrl(dirty);
  assert.strictEqual(res.isValid, true);
  assert.strictEqual(res.cleanedUrl, "https://www.instagram.com/p/C3XYZ123/");
  assert(res.trackersRemoved.includes("igsh"));
});

// 7. TikTok tracking parameters
test("Strips TikTok tracking parameters (_r, _t, checksum, is_from_webapp)", () => {
  const dirty = "https://www.tiktok.com/@user/video/1234567890?_r=1&_t=8Wxyz&is_from_webapp=1&sender_device=pc";
  const res = Engine.cleanUrl(dirty);
  assert.strictEqual(res.isValid, true);
  assert.strictEqual(res.cleanedUrl, "https://www.tiktok.com/@user/video/1234567890");
  assert(res.trackersRemoved.includes("_r"));
  assert(res.trackersRemoved.includes("is_from_webapp"));
});

// 8. Amazon product URL normalization
test("Normalizes Amazon product URL to canonical dp/ASIN", () => {
  const dirty = "https://www.amazon.com/Apple-MacBook-14-inch-8-core-512GB/dp/B09JQL8KP9/ref=sr_1_1?crid=123&keywords=macbook&qid=1680000000&sprefix=macbook%2Caps%2C123&sr=8-1";
  const res = Engine.cleanUrl(dirty);
  assert.strictEqual(res.isValid, true);
  assert.strictEqual(res.cleanedUrl, "https://www.amazon.com/dp/B09JQL8KP9");
  assert(res.trackersRemoved.includes("amazon_referrals"));
});

// 9. Spotify tracking parameter
test("Strips Spotify share tracker (si, context)", () => {
  const dirty = "https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT?si=a1b2c3d4e5f6g7h8&context=spotify%3Aplaylist%3A123";
  const res = Engine.cleanUrl(dirty);
  assert.strictEqual(res.isValid, true);
  assert.strictEqual(res.cleanedUrl, "https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT");
  assert(res.trackersRemoved.includes("si"));
});

// 10. Redirect wrapper unwrapping (Google URL)
test("Unwraps Google redirect wrapper", () => {
  const wrapped = "https://www.google.com/url?q=https://example.com/target-page&sa=D&sntz=1&usg=AFQjCN...";
  const res = Engine.cleanUrl(wrapped);
  assert.strictEqual(res.isValid, true);
  assert.strictEqual(res.cleanedUrl, "https://example.com/target-page");
  assert(res.trackersRemoved.includes("redirect_wrapper"));
});

// 11. Redirect wrapper unwrapping (Facebook redirect)
test("Unwraps Facebook redirect wrapper", () => {
  const wrapped = "https://l.facebook.com/l.php?u=https%3A%2F%2Fclean-target.org%2Fpage%3Futm_source%3Dfb";
  const res = Engine.cleanUrl(wrapped);
  assert.strictEqual(res.isValid, true);
  assert.strictEqual(res.cleanedUrl, "https://clean-target.org/page");
  assert(res.trackersRemoved.includes("redirect_wrapper"));
  assert(res.trackersRemoved.includes("utm_source"));
});

// 12. Non-URL input handling
test("Handles non-URL input gracefully", () => {
  const res = Engine.cleanUrl("This is just some plain text without any url");
  assert.strictEqual(res.isValid, false);
  assert.strictEqual(res.cleanedUrl, "");
});

// 13. URL without protocol (e.g. example.com?utm_source=abc)
test("Handles URL without protocol scheme", () => {
  const res = Engine.cleanUrl("github.com/torvalds/linux?utm_source=twitter");
  assert.strictEqual(res.isValid, true);
  assert.strictEqual(res.cleanedUrl, "https://github.com/torvalds/linux");
});

// 14. Text with surrounding whitespace
test("Handles URL with surrounding whitespace", () => {
  const res = Engine.cleanUrl("   \n https://example.com/test?gclid=12345 \t\n ");
  assert.strictEqual(res.isValid, true);
  assert.strictEqual(res.cleanedUrl, "https://example.com/test");
  assert(res.trackersRemoved.includes("gclid"));
});

// 15. LinkedIn tracking parameters
test("Strips LinkedIn tracking parameters (trackingId, trk, refId)", () => {
  const dirty = "https://www.linkedin.com/posts/activity-123456789?utm_source=share&utm_medium=member_desktop&trackingId=xyz123&refId=abc789";
  const res = Engine.cleanUrl(dirty);
  assert.strictEqual(res.isValid, true);
  assert.strictEqual(res.cleanedUrl, "https://www.linkedin.com/posts/activity-123456789");
  assert(res.trackersRemoved.includes("utm_source"));
  assert(res.trackersRemoved.includes("trackingId"));
});

// 16. AliExpress tracking parameters
test("Strips AliExpress tracking parameters (spm, scm, aff_fcid)", () => {
  const dirty = "https://www.aliexpress.com/item/1005001234567890.html?spm=a2g0o.productlist.0.0&scm=1007.123&aff_fcid=abc123xyz";
  const res = Engine.cleanUrl(dirty);
  assert.strictEqual(res.isValid, true);
  assert.strictEqual(res.cleanedUrl, "https://www.aliexpress.com/item/1005001234567890.html");
  assert(res.trackersRemoved.includes("spm"));
});

// 17. Mercado Livre / Google Ads tracking parameters
test("Strips Mercado Livre / Google shopping tracking parameters", () => {
  const dirty = "https://www.mercadolivre.com.br/tablet-xiaomi/p/MLB63329668?pdp_filters=item_id%3AMLB4626846513&from=gshop&matt_tool=43870358&matt_source=google&matt_campaign_id=23355339253&cq_src=google_ads&cq_cmp=23355339253&gad_source=1";
  const res = Engine.cleanUrl(dirty);
  assert.strictEqual(res.isValid, true);
  assert.strictEqual(res.cleanedUrl, "https://www.mercadolivre.com.br/tablet-xiaomi/p/MLB63329668");
  assert(res.trackersCount >= 7);
});

// 18. Tracking hash fragment removal (#xtor, #:~:text=)
test("Strips tracking fragment (#xtor, #:~:text=)", () => {
  const dirty = "https://example.com/article?page=2#xtor=RSS-123";
  const res = Engine.cleanUrl(dirty);
  assert.strictEqual(res.isValid, true);
  assert.strictEqual(res.cleanedUrl, "https://example.com/article?page=2");
  assert(res.trackersRemoved.includes("hash_tracker"));
});

// 19. QR Code generation validation (short & long strings)
test("Generates QR code matrix correctly for both short and long text", () => {
  const shortMatrix = QRCode.generateMatrix("https://example.com", "M");
  assert(Array.isArray(shortMatrix));
  assert(shortMatrix.length >= 21);
  assert.strictEqual(shortMatrix[0][0], true);

  const longUrl = "https://example.com/very/long/path/with/lots/of/parameters/that/exceeds/hundreds/of/characters/for/testing/qr/code/generator/version/selection/to/ensure/it/does/not/fail/or/throw/errors/on/long/strings/repeated/".repeat(3);
  const longMatrix = QRCode.generateMatrix(longUrl, "L");
  assert(Array.isArray(longMatrix));
  assert(longMatrix.length > 50);
});

// 20. YouTube Shorts normalization
test("Normalizes YouTube Shorts to standard watch URL", () => {
  const dirty = "https://www.youtube.com/shorts/dQw4w9WgXcQ?si=abcdef&feature=share";
  const res = Engine.cleanUrl(dirty);
  assert.strictEqual(res.isValid, true);
  assert.strictEqual(res.cleanedUrl, "https://www.youtube.com/watch?v=dQw4w9WgXcQ");
  assert(res.trackersRemoved.includes("youtube_shorts"));
  assert(res.trackersRemoved.includes("si"));
});

// 21. Steam and Twitch trackers
test("Strips Steam and Twitch tracking parameters", () => {
  const steamDirty = "https://store.steampowered.com/app/1091500/Cyberpunk_2077/?snr=1_4_4__118";
  const steamRes = Engine.cleanUrl(steamDirty);
  assert.strictEqual(steamRes.cleanedUrl, "https://store.steampowered.com/app/1091500/Cyberpunk_2077/");

  const twitchDirty = "https://www.twitch.tv/directory/game/Minecraft?tt_medium=app&tt_content=share";
  const twitchRes = Engine.cleanUrl(twitchDirty);
  assert.strictEqual(twitchRes.cleanedUrl, "https://www.twitch.tv/directory/game/Minecraft");
});

// 22. Newsletter & CRM tokens
test("Strips Newsletter and CRM click trackers", () => {
  const dirty = "https://example.com/blog?vgo_ee=abcdef&mbid=synd_123&mc_cid=98765&hsa_cam=456";
  const res = Engine.cleanUrl(dirty);
  assert.strictEqual(res.cleanedUrl, "https://example.com/blog");
  assert.strictEqual(res.trackersCount, 4);
});

// 23. Whitelist / preserveParams support
test("Preserves whitelisted parameters with preserveParams option", () => {
  const dirty = "https://example.com/item?utm_source=twitter&ref=creator123&tag=mypartner";
  const res = Engine.cleanUrl(dirty, { preserveParams: ["ref", "tag"] });
  assert.strictEqual(res.cleanedUrl, "https://example.com/item?ref=creator123&tag=mypartner");
  assert.strictEqual(res.trackersCount, 1);
  assert(res.trackersRemoved.includes("utm_source"));
});

// 24. Shortener domain detection
test("Identifies known shortener domains", () => {
  const res1 = Engine.cleanUrl("https://bit.ly/3xYz123");
  assert.strictEqual(res1.isShortener, true);

  const res2 = Engine.cleanUrl("https://t.co/abc123xyz");
  assert.strictEqual(res2.isShortener, true);

  const res3 = Engine.cleanUrl("https://github.com/torvalds/linux");
  assert.strictEqual(res3.isShortener, false);
});

console.log(`\nResults: ${passed} / ${total} tests passed.`);
if (passed !== total) process.exit(1);
