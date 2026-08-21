// Engine.js — Pure JavaScript URL Cleaner & Tracker Stripper
// Part of DeTrack (https://github.com/jvlianodorneles/DeTrack)

// Universal tracking parameters stripped from all domains
var GLOBAL_TRACKING_PARAMS = [
  // Google / Analytics / Ads
  "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
  "utm_id", "utm_name", "utm_cid", "utm_reader", "utm_viz_id", "utm_pubreferrer",
  "utm_swu", "utm_brand", "utm_social", "utm_social-type", "utm_place", "utm_userid",
  "gclid", "gclsrc", "dclid", "wbraid", "gbraid", "gad_source", "gad_campaignid",
  "_ga", "_gl", "_hsenc", "_hsmi", "mc_eid", "mc_cid", "mkt_tok",

  // Facebook / Meta / Instagram
  "fbclid", "fb_action_ids", "fb_action_types", "fb_source", "fb_ref", "fref",
  "hbad", "igshid", "igsh",

  // TikTok
  "_r", "_t", "checksum", "tt_from", "is_from_webapp", "sender_device",

  // Twitter / X
  "twclid", "ref_src", "ref_url",

  // Microsoft / Bing
  "msclkid", "cvid", "ocid",

  // Yandex, Yahoo & Mail.ru
  "yclid", "ym_debug", "_openstat", "guccounter", "guce_referrer", "guce_referrer_usqp",

  // General Marketing / Email / CRM / Affiliate / Ads
  "wickedid", "wt_mc", "wt_zmc", "vero_id", "vero_conv", "nr_email_referer",
  "sc_campaign", "sc_channel", "sc_content", "sc_country", "sc_geo", "sc_medium",
  "sc_outcome", "sc_params", "sc_publisher", "sc_segment", "sc_term", "sc_cid",
  "trk_contact", "trk_msg", "trk_module", "trk_sid",
  "matomo_campaign", "matomo_kwd", "mtm_campaign", "mtm_kwd",
  "pk_campaign", "pk_kwd", "piwik_campaign", "piwik_kwd",
  "zanpid", "clickref", "click_id", "clickid", "aff_trace_key", "aff_platform", "aff_fcid", "aff_fsk", "afftrack",
  "spm", "scm", "algo_pvid", "algo_expid", "btsid", "ws_ab_test",
  "share_id", "trackingId", "refId", "trkEmail", "midToken", "midSig", "lipi", "licu",
  "vgo_ee", "mbid", "cmpid", "bta_c", "bta_tid", "esheet", "irgwc", "irclickid", "rb_clickid",
  "s_cid", "elqTrackId", "elqTrack", "recipient_id",
  "hsa_cam", "hsa_grp", "hsa_mt", "hsa_src", "hsa_ad", "hsa_acc", "hsa_net", "hsa_kw", "hsa_tgt", "hsa_ver"
];

// Domain-specific parameter filters
var DOMAIN_SPECIFIC_PARAMS = {
  "youtube.com": ["si", "pp", "feature", "ab_channel", "sub_confirmation", "embeds_referring_euri", "source_ve_path"],
  "youtu.be": ["si", "pp", "feature", "ab_channel", "sub_confirmation"],
  "tiktok.com": ["_r", "_t", "checksum", "tt_from", "is_from_webapp", "sender_device"],
  "twitter.com": ["s", "t", "cn"],
  "x.com": ["s", "t", "cn"],
  "reddit.com": ["ref", "ref_source", "rdt"],
  "spotify.com": ["si", "context", "nd", "pt"],
  "open.spotify.com": ["si", "context", "nd", "pt"],
  "linkedin.com": ["trk", "refId", "trackingId", "midToken"],
  "aliexpress.com": ["spm", "scm", "aff_fcid", "aff_fsk", "aff_platform", "aff_trace_key"],
  "twitch.tv": ["tt_medium", "tt_content", "sr"],
  "steampowered.com": ["snr", "curator_clanid"],
  "bilibili.com": ["spm_id_from", "from_source", "from", "seid"],
  "medium.com": ["source", "postPublishedGoogleUrl"],
  "substack.com": ["utm_source", "utm_medium", "utm_campaign", "publication_id", "post_id", "r"],
  "mercadolivre.com.br": [
    "pdp_filters", "from", "matt_tool", "matt_word", "matt_source", "matt_campaign_id",
    "matt_ad_group_id", "matt_match_type", "matt_network", "matt_device", "matt_creative",
    "matt_keyword", "matt_ad_position", "matt_ad_type", "matt_merchant_id", "matt_product_id",
    "matt_product_partition_id", "matt_target_id", "cq_src", "cq_cmp", "cq_net", "cq_plt", "cq_med"
  ],
  "mercadolibre.com": [
    "pdp_filters", "from", "matt_tool", "matt_word", "matt_source", "matt_campaign_id",
    "matt_ad_group_id", "matt_match_type", "matt_network", "matt_device", "matt_creative",
    "matt_keyword", "matt_ad_position", "matt_ad_type", "matt_merchant_id", "matt_product_id",
    "matt_product_partition_id", "matt_target_id", "cq_src", "cq_cmp", "cq_net", "cq_plt", "cq_med"
  ],
  "amazon.com": [
    "ref_", "ref", "tag", "psc", "keywords", "qid", "sr", "crid", "sprefix",
    "dib", "dib_tag", "pd_rd_w", "pd_rd_wg", "pd_rd_r", "pf_rd_p", "pf_rd_r",
    "pf_rd_m", "pf_rd_s", "pf_rd_t", "pf_rd_i", "content-id"
  ]
};

// Known shortener domains
var SHORTENER_DOMAINS = [
  "bit.ly", "tinyurl.com", "t.co", "cutt.ly", "is.gd", "buff.ly", "trib.al",
  "qr.ae", "rb.gy", "shorturl.at", "ow.ly", "goo.gl", "rebrand.ly", "bl.ink",
  "tiny.cc", "s.id", "clck.ru", "snip.ly"
];

// Known redirect wrappers to unwrap
var REDIRECT_WRAPPERS = [
  { pattern: /^https?:\/\/(?:www\.)?google\.[a-z.]+\/url\?/i, param: "q" },
  { pattern: /^https?:\/\/(?:www\.)?google\.[a-z.]+\/url\?/i, param: "url" },
  { pattern: /^https?:\/\/l\.facebook\.com\/l\.php\?/i, param: "u" },
  { pattern: /^https?:\/\/lm\.facebook\.com\/l\.php\?/i, param: "u" },
  { pattern: /^https?:\/\/out\.reddit\.com\/?\?/i, param: "url" },
  { pattern: /^https?:\/\/href\.li\/\?/i, directQuery: true },
  { pattern: /^https?:\/\/gate\.sc\/\?/i, param: "url" },
  { pattern: /^https?:\/\/slack-redir\.net\/link\?/i, param: "url" }
];

/**
 * Checks if a string is a candidate URL without markup, control characters, or invalid hostnames.
 */
function isUrl(text) {
  if (!text || typeof text !== "string") return false;
  var trimmed = text.trim();
  if (trimmed.length < 4 || trimmed.length > 8192) return false;
  if (/\s/.test(trimmed)) return false; // URLs cannot contain whitespace
  if (/[<>"'`\\^|]/.test(trimmed)) return false; // Reject HTML/markup and unsafe characters

  var urlPattern = /^(?:https?|ftps?):\/\/(?:[a-zA-Z0-9](?:[a-zA-Z0-9.-]*[a-zA-Z0-9])?|\[[a-fA-F0-9:]+\])(?::\d+)?(?:\/[^\s<>"'`\\^|]*)?$/i;
  var bareDomainPattern = /^[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}(?::\d+)?(?:\/[^\s<>"'`\\^|]*)?$/i;

  return urlPattern.test(trimmed) || bareDomainPattern.test(trimmed);
}

/**
 * Extracts candidate URL from arbitrary text (e.g. copied text containing a URL).
 */
function extractUrl(text) {
  if (!text || typeof text !== "string") return "";
  var trimmed = text.trim();
  if (isUrl(trimmed)) {
    if (!/^[a-zA-Z][a-zA-Z0-9+.-]*:\/\//i.test(trimmed)) {
      return "https://" + trimmed;
    }
    return trimmed;
  }
  var match = text.match(/https?:\/\/(?:[a-zA-Z0-9](?:[a-zA-Z0-9.-]*[a-zA-Z0-9])?|\[[a-fA-F0-9:]+\])(?::\d+)?(?:\/[^\s<>"'`\\^|]*)?/i);
  if (match && isUrl(match[0])) {
    return match[0];
  }
  return "";
}

/**
 * Checks if hostname is a known shortener service.
 */
function isShortenerDomain(hostname) {
  if (!hostname) return false;
  var h = hostname.toLowerCase().replace(/^www\./, "");
  for (var i = 0; i < SHORTENER_DOMAINS.length; i++) {
    if (h === SHORTENER_DOMAINS[i] || h.endsWith("." + SHORTENER_DOMAINS[i])) {
      return true;
    }
  }
  return false;
}

/**
 * Parses query string into array of { key, value, raw } preserving order.
 */
function parseQueryParams(queryString) {
  if (!queryString) return [];
  var result = [];
  var cleanQuery = queryString.startsWith("?") ? queryString.slice(1) : queryString;
  if (!cleanQuery) return [];

  var pairs = cleanQuery.split("&");
  for (var i = 0; i < pairs.length; i++) {
    var pair = pairs[i];
    if (!pair) continue;
    var eqIdx = pair.indexOf("=");
    if (eqIdx >= 0) {
      result.push({
        key: pair.slice(0, eqIdx),
        value: pair.slice(eqIdx + 1),
        raw: pair
      });
    } else {
      result.push({
        key: pair,
        value: "",
        raw: pair
      });
    }
  }
  return result;
}

/**
 * Builds query string from array of param objects.
 */
function buildQueryString(params) {
  if (!params || params.length === 0) return "";
  var parts = [];
  for (var i = 0; i < params.length; i++) {
    var p = params[i];
    if (p.value !== "") {
      parts.push(p.key + "=" + p.value);
    } else {
      parts.push(p.key);
    }
  }
  return parts.length > 0 ? "?" + parts.join("&") : "";
}

/**
 * Unwraps redirect wrappers if present.
 */
function unwrapRedirect(url) {
  for (var i = 0; i < REDIRECT_WRAPPERS.length; i++) {
    var wrapper = REDIRECT_WRAPPERS[i];
    if (wrapper.pattern.test(url)) {
      if (wrapper.directQuery) {
        var idx = url.indexOf("?");
        if (idx >= 0 && idx < url.length - 1) {
          var target = url.slice(idx + 1);
          if (isUrl(target)) return decodeURIComponent(target);
        }
      } else if (wrapper.param) {
        var qIdx = url.indexOf("?");
        if (qIdx >= 0) {
          var params = parseQueryParams(url.slice(qIdx));
          for (var p = 0; p < params.length; p++) {
            if (params[p].key === wrapper.param) {
              var targetVal = decodeURIComponent(params[p].value);
              if (isUrl(targetVal)) return targetVal;
            }
          }
        }
      }
    }
  }
  return url;
}

/**
 * Extracts hostname from URL.
 */
function getHostname(url) {
  try {
    var match = url.match(/^https?:\/\/([^/?#:]+)/i);
    return match ? match[1].toLowerCase() : "";
  } catch (e) {
    return "";
  }
}

/**
 * Checks if a parameter key matches known tracking filters for given host.
 */
function isTrackingParam(key, hostname, preserveParams) {
  if (!key) return false;
  var lowerKey = key.toLowerCase();

  // Whitelist check
  if (preserveParams && Array.isArray(preserveParams)) {
    for (var w = 0; w < preserveParams.length; w++) {
      if (lowerKey === String(preserveParams[w]).toLowerCase()) {
        return false;
      }
    }
  }

  // Known prefix matches
  if (lowerKey.startsWith("utm_") ||
      lowerKey.startsWith("matt_") ||
      lowerKey.startsWith("cq_") ||
      lowerKey.startsWith("gad_") ||
      lowerKey.startsWith("gcl") ||
      lowerKey.startsWith("mc_") ||
      lowerKey.startsWith("sc_") ||
      lowerKey.startsWith("pk_") ||
      lowerKey.startsWith("piwik_") ||
      lowerKey.startsWith("matomo_") ||
      lowerKey.startsWith("mtm_") ||
      lowerKey.startsWith("wt_") ||
      lowerKey.startsWith("vero_") ||
      lowerKey.startsWith("fb_") ||
      lowerKey.startsWith("tw_") ||
      lowerKey.startsWith("hsa_")) {
    return true;
  }

  // Exact global tracker check
  for (var i = 0; i < GLOBAL_TRACKING_PARAMS.length; i++) {
    var p = GLOBAL_TRACKING_PARAMS[i];
    if (lowerKey === p) {
      return true;
    }
  }

  // Domain-specific check
  for (var dom in DOMAIN_SPECIFIC_PARAMS) {
    if (hostname.indexOf(dom) !== -1) {
      var specificList = DOMAIN_SPECIFIC_PARAMS[dom];
      for (var s = 0; s < specificList.length; s++) {
        var spec = specificList[s].toLowerCase();
        if (lowerKey === spec || lowerKey.startsWith(spec)) {
          return true;
        }
      }
    }
  }

  return false;
}

/**
 * Normalizes Amazon product URLs: transforms long search/referral paths into canonical amazon.com/dp/ASIN.
 */
function normalizeAmazonUrl(url) {
  var asinMatch = url.match(/(?:https?:\/\/)?(?:www\.)?amazon\.(com|co\.uk|de|com\.br|es|fr|it|co\.jp|ca|in|com\.mx|nl|se|pl|com\.au|com\.be)\/(?:[^\/]+\/)?(?:dp|gp\/product|d)\/([A-Z0-9]{10})/i);
  if (asinMatch) {
    var tld = asinMatch[1];
    var asin = asinMatch[2];
    return "https://www.amazon." + tld + "/dp/" + asin;
  }
  return null;
}

/**
 * Normalizes YouTube shorts to canonical watch URL.
 */
function normalizeYouTubeShorts(url) {
  var m = url.match(/^(https?:\/\/(?:www\.)?youtube\.com)\/shorts\/([a-zA-Z0-9_-]{11})([^#?]*)(.*)$/i);
  if (m) {
    var domain = m[1];
    var videoId = m[2];
    var rest = m[4] || "";
    var hashIdx = rest.indexOf("#");
    var query = "";
    var hash = "";
    if (hashIdx >= 0) {
      hash = rest.slice(hashIdx);
      query = rest.slice(0, hashIdx);
    } else {
      query = rest;
    }
    if (query && query.length > 1) {
      return domain + "/watch?v=" + videoId + "&" + query.slice(1) + hash;
    }
    return domain + "/watch?v=" + videoId + hash;
  }
  return null;
}

/**
 * Main URL sanitizing function.
 * @param {string} rawInput - Clipboard text or typed URL.
 * @param {object} [options] - Optional settings { preserveParams: string[], normalizeShorts: boolean }.
 * @returns {object} Cleaned result object.
 */
function cleanUrl(rawInput, options) {
  var opts = options || {};
  var preserveParams = opts.preserveParams || [];

  var res = {
    isValid: false,
    originalUrl: (rawInput || "").trim(),
    cleanedUrl: "",
    trackersRemoved: [],
    trackersCount: 0,
    charsSaved: 0,
    domain: "",
    isShortener: false,
    message: ""
  };

  if (!rawInput || typeof rawInput !== "string") {
    res.message = "No input provided";
    return res;
  }

  var extracted = extractUrl(rawInput);
  if (!extracted) {
    res.message = "No valid URL found in input";
    return res;
  }

  // Ensure protocol
  var currentUrl = extracted;
  if (!/^[a-zA-Z][a-zA-Z0-9+.-]*:\/\//i.test(currentUrl)) {
    currentUrl = "https://" + currentUrl;
  }

  // Unwrap redirect if present
  var unwrapped = unwrapRedirect(currentUrl);
  if (unwrapped !== currentUrl) {
    res.trackersRemoved.push("redirect_wrapper");
    currentUrl = unwrapped;
  }

  // Check Amazon normalization
  var amazonClean = normalizeAmazonUrl(currentUrl);
  if (amazonClean) {
    var origLen = currentUrl.length;
    res.isValid = true;
    res.originalUrl = extracted;
    res.cleanedUrl = amazonClean;
    res.domain = getHostname(amazonClean);
    res.trackersRemoved.push("amazon_referrals");
    res.trackersCount = 1;
    res.charsSaved = Math.max(0, origLen - amazonClean.length);
    res.message = "Normalized Amazon product URL";
    return res;
  }

  // Check YouTube Shorts normalization (optional/default on)
  if (opts.normalizeShorts !== false) {
    var ytNormalized = normalizeYouTubeShorts(currentUrl);
    if (ytNormalized) {
      res.trackersRemoved.push("youtube_shorts");
      currentUrl = ytNormalized;
    }
  }

  // Split URL into base, query, fragment
  var hashIdx = currentUrl.indexOf("#");
  var fragment = "";
  if (hashIdx >= 0) {
    fragment = currentUrl.slice(hashIdx);
    currentUrl = currentUrl.slice(0, hashIdx);
  }

  var queryIdx = currentUrl.indexOf("?");
  var baseUrl = currentUrl;
  var queryString = "";
  if (queryIdx >= 0) {
    baseUrl = currentUrl.slice(0, queryIdx);
    queryString = currentUrl.slice(queryIdx);
  }

  var hostname = getHostname(baseUrl);
  res.domain = hostname;
  res.isShortener = isShortenerDomain(hostname);

  var params = parseQueryParams(queryString);
  var keptParams = [];
  var removed = [];

  for (var i = 0; i < params.length; i++) {
    var p = params[i];
    if (isTrackingParam(p.key, hostname, preserveParams)) {
      removed.push(p.key);
    } else {
      keptParams.push(p);
    }
  }

  // Clean tracking fragment if present
  if (fragment && (/^#(?:xtor|utm_)/i.test(fragment) || /^#:~:text=/i.test(fragment))) {
    removed.push("hash_tracker");
    fragment = "";
  }

  var cleanedQuery = buildQueryString(keptParams);
  var finalUrl = baseUrl + cleanedQuery + fragment;

  res.isValid = true;
  res.originalUrl = extracted;
  res.cleanedUrl = finalUrl;
  res.trackersRemoved = res.trackersRemoved.concat(removed);
  res.trackersCount = res.trackersRemoved.length;
  res.charsSaved = Math.max(0, extracted.length - finalUrl.length);

  if (res.trackersCount > 0) {
    res.message = "Cleaned " + res.trackersCount + " tracker" + (res.trackersCount > 1 ? "s" : "");
  } else {
    res.message = "URL is clean";
  }

  return res;
}

// Export for CommonJS (Node.js tests) if available
if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    cleanUrl: cleanUrl,
    extractUrl: extractUrl,
    isUrl: isUrl,
    isShortenerDomain: isShortenerDomain,
    unwrapRedirect: unwrapRedirect,
    normalizeAmazonUrl: normalizeAmazonUrl,
    normalizeYouTubeShorts: normalizeYouTubeShorts,
    GLOBAL_TRACKING_PARAMS: GLOBAL_TRACKING_PARAMS,
    DOMAIN_SPECIFIC_PARAMS: DOMAIN_SPECIFIC_PARAMS,
    SHORTENER_DOMAINS: SHORTENER_DOMAINS
  };
}
