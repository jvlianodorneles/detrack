#!/usr/bin/env python3
"""
DeTrack CLI — Fast URL Tracker Cleaner & QR Code Generator
Part of DeTrack (https://github.com/jvlianodorneles/DeTrack)
"""

import sys
import os
import re
import json
import socket
import ipaddress
import argparse
import subprocess
import urllib.parse
import urllib.request

GLOBAL_TRACKING_PARAMS = {
    # Google / Analytics / Ads
    "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
    "utm_id", "utm_name", "utm_cid", "utm_reader", "utm_viz_id", "utm_pubreferrer",
    "utm_swu", "utm_brand", "utm_social", "utm_social-type", "utm_place", "utm_userid",
    "gclid", "gclsrc", "dclid", "wbraid", "gbraid", "gad_source", "gad_campaignid",
    "_ga", "_gl", "_hsenc", "_hsmi", "mc_eid", "mc_cid", "mkt_tok",

    # Facebook / Meta / Instagram
    "fbclid", "fb_action_ids", "fb_action_types", "fb_source", "fb_ref", "fref",
    "hbad", "igshid", "igsh",

    # TikTok
    "_r", "_t", "checksum", "tt_from", "is_from_webapp", "sender_device",

    # Twitter / X
    "twclid", "ref_src", "ref_url",

    # Microsoft / Bing
    "msclkid", "cvid", "ocid",

    # Yandex, Yahoo & Mail.ru
    "yclid", "ym_debug", "_openstat", "guccounter", "guce_referrer", "guce_referrer_usqp",

    # General Marketing / Affiliate / CRM / Ads
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
}

DOMAIN_SPECIFIC_PARAMS = {
    "youtube.com": {"si", "pp", "feature", "ab_channel", "sub_confirmation", "embeds_referring_euri", "source_ve_path"},
    "youtu.be": {"si", "pp", "feature", "ab_channel", "sub_confirmation"},
    "tiktok.com": {"_r", "_t", "checksum", "tt_from", "is_from_webapp", "sender_device"},
    "twitter.com": {"s", "t", "cn"},
    "x.com": {"s", "t", "cn"},
    "reddit.com": {"ref", "ref_source", "rdt"},
    "spotify.com": {"si", "context", "nd", "pt"},
    "open.spotify.com": {"si", "context", "nd", "pt"},
    "linkedin.com": {"trk", "refId", "trackingId", "midToken"},
    "aliexpress.com": {"spm", "scm", "aff_fcid", "aff_fsk", "aff_platform", "aff_trace_key"},
    "twitch.tv": {"tt_medium", "tt_content", "sr"},
    "steampowered.com": {"snr", "curator_clanid"},
    "bilibili.com": {"spm_id_from", "from_source", "from", "seid"},
    "medium.com": {"source", "postPublishedGoogleUrl"},
    "substack.com": {"utm_source", "utm_medium", "utm_campaign", "publication_id", "post_id", "r"},
    "mercadolivre.com.br": {
        "pdp_filters", "from", "matt_tool", "matt_word", "matt_source", "matt_campaign_id",
        "matt_ad_group_id", "matt_match_type", "matt_network", "matt_device", "matt_creative",
        "matt_keyword", "matt_ad_position", "matt_ad_type", "matt_merchant_id", "matt_product_id",
        "matt_product_partition_id", "matt_target_id", "cq_src", "cq_cmp", "cq_net", "cq_plt", "cq_med"
    },
    "mercadolibre.com": {
        "pdp_filters", "from", "matt_tool", "matt_word", "matt_source", "matt_campaign_id",
        "matt_ad_group_id", "matt_match_type", "matt_network", "matt_device", "matt_creative",
        "matt_keyword", "matt_ad_position", "matt_ad_type", "matt_merchant_id", "matt_product_id",
        "matt_product_partition_id", "matt_target_id", "cq_src", "cq_cmp", "cq_net", "cq_plt", "cq_med"
    },
    "amazon.com": {
        "ref_", "ref", "tag", "psc", "keywords", "qid", "sr", "crid", "sprefix",
        "dib", "dib_tag", "pd_rd_w", "pd_rd_wg", "pd_rd_r", "pf_rd_p", "pf_rd_r",
        "pf_rd_m", "pf_rd_s", "pf_rd_t", "pf_rd_i", "content-id"
    }
}

SHORTENER_DOMAINS = {
    "bit.ly", "tinyurl.com", "t.co", "cutt.ly", "is.gd", "buff.ly", "trib.al",
    "qr.ae", "rb.gy", "shorturl.at", "ow.ly", "goo.gl", "rebrand.ly", "bl.ink",
    "tiny.cc", "s.id", "clck.ru", "snip.ly"
}

REDIRECT_PATTERNS = [
    (re.compile(r"^https?://(?:www\.)?google\.[a-z.]+/url\?", re.I), "q"),
    (re.compile(r"^https?://(?:www\.)?google\.[a-z.]+/url\?", re.I), "url"),
    (re.compile(r"^https?://l\.facebook\.com/l\.php\?", re.I), "u"),
    (re.compile(r"^https?://lm\.facebook\.com/l\.php\?", re.I), "u"),
    (re.compile(r"^https?://out\.reddit\.com/?\?", re.I), "url"),
    (re.compile(r"^https?://gate\.sc/\?", re.I), "url"),
    (re.compile(r"^https?://slack-redir\.net/link\?", re.I), "url"),
]

def is_url(text: str) -> bool:
    if not text or not isinstance(text, str):
        return False
    t = text.strip()
    if len(t) < 4 or len(t) > 8192 or any(c.isspace() for c in t):
        return False
    if re.search(r'[<>\'\"`\\^|]', t):
        return False
    url_pattern = r'^(?:https?|ftps?)://(?:[a-zA-Z0-9](?:[a-zA-Z0-9.-]*[a-zA-Z0-9])?|\[[a-fA-F0-9:]+\])(?::\d+)?(?:[/?#][^\s<>\'\"`\\^|]*)?$'
    bare_domain_pattern = r'^[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}(?::\d+)?(?:[/?#][^\s<>\'\"`\\^|]*)?$'
    return bool(re.match(url_pattern, t, re.I) or re.match(bare_domain_pattern, t, re.I))

def extract_url(text: str) -> str:
    if not text:
        return ""
    t = text.strip()
    if is_url(t):
        if not re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*://", t, re.I):
            return "https://" + t
        return t
    m = re.search(r"https?://(?:[a-zA-Z0-9](?:[a-zA-Z0-9.-]*[a-zA-Z0-9])?|\[[a-fA-F0-9:]+\])(?::\d+)?(?:[/?#][^\s<>\'\"`\\^|]*)?", text, re.I)
    if m and is_url(m.group(0)):
        return m.group(0)
    return ""

def is_shortener_domain(hostname: str) -> bool:
    if not hostname:
        return False
    h = hostname.lower().replace("www.", "")
    return h in SHORTENER_DOMAINS or any(h.endswith("." + s) for s in SHORTENER_DOMAINS)

def unwrap_redirect(url: str) -> tuple[str, bool]:
    for pattern, param in REDIRECT_PATTERNS:
        if pattern.match(url):
            parsed = urllib.parse.urlparse(url)
            qs = urllib.parse.parse_qs(parsed.query)
            if param in qs and qs[param]:
                target = qs[param][0]
                if is_url(target):
                    return target, True
    if re.match(r"^https?://href\.li/\?", url, re.I):
        idx = url.find("?")
        if idx >= 0 and idx < len(url) - 1:
            target = urllib.parse.unquote(url[idx + 1:])
            if is_url(target):
                return target, True
    return url, False

def normalize_amazon(url: str) -> str | None:
    m = re.search(r"(?:https?://)?(?:www\.)?amazon\.(com|co\.uk|de|com\.br|es|fr|it|co\.jp|ca|in|com\.mx|nl|se|pl|com\.au|com\.be)/(?:[^/]+/)?(?:dp|gp/product|d)/([A-Z0-9]{10})", url, re.I)
    if m:
        return f"https://www.amazon.{m.group(1)}/dp/{m.group(2)}"
    return None

def normalize_youtube_shorts(url: str) -> str | None:
    m = re.match(r"^(https?://(?:www\.)?youtube\.com)/shorts/([a-zA-Z0-9_-]{11})([^#?]*)(.*)$", url, re.I)
    if m:
        domain, video_id, _, rest = m.groups()
        hash_idx = rest.find("#")
        query = rest[:hash_idx] if hash_idx >= 0 else rest
        frag = rest[hash_idx:] if hash_idx >= 0 else ""
        if query and len(query) > 1:
            return f"{domain}/watch?v={video_id}&{query[1:]}{frag}"
        return f"{domain}/watch?v={video_id}{frag}"
    return None

def is_tracking_param(key: str, hostname: str, preserve_params: set | None = None) -> bool:
    try:
        decoded_key = urllib.parse.unquote(key)
    except Exception:
        decoded_key = key
    lk = decoded_key.lower()
    if preserve_params and lk in preserve_params:
        return False

    if (lk.startswith("utm_") or lk.startswith("matt_") or lk.startswith("cq_") or
        lk.startswith("gad_") or lk.startswith("gcl") or lk.startswith("mc_") or
        lk.startswith("sc_") or lk.startswith("pk_") or lk.startswith("piwik_") or
        lk.startswith("matomo_") or lk.startswith("mtm_") or lk.startswith("wt_") or
        lk.startswith("vero_") or lk.startswith("fb_") or lk.startswith("tw_") or
        lk.startswith("hsa_")):
        return True

    if lk in GLOBAL_TRACKING_PARAMS:
        return True

    for dom, params in DOMAIN_SPECIFIC_PARAMS.items():
        if dom in hostname:
            if lk in params:
                return True
            for p in params:
                if lk.startswith(p):
                    return True
    return False

def is_safe_target_url(url: str) -> bool:
    try:
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme.lower() not in ("http", "https"):
            return False
        hostname = parsed.hostname
        if not hostname:
            return False
        if hostname.lower() in ("localhost", "ip6-localhost", "ip6-loopback"):
            return False
        try:
            addr_info = socket.getaddrinfo(hostname, None, socket.AF_UNSPEC, socket.SOCK_STREAM)
            for _, _, _, _, sockaddr in addr_info:
                ip_str = sockaddr[0]
                ip = ipaddress.ip_address(ip_str)
                if ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_multicast or ip.is_reserved or ip.is_unspecified:
                    return False
        except Exception:
            return False
        return True
    except Exception:
        return False

class SafeRedirectHandler(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if not is_safe_target_url(newurl):
            return None
        return super().redirect_request(req, fp, code, msg, headers, newurl)

def unshorten_url(url: str) -> str:
    try:
        if not is_safe_target_url(url):
            return url
        opener = urllib.request.build_opener(SafeRedirectHandler)
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"})
        with opener.open(req, timeout=4) as resp:
            target = resp.geturl()
            if is_safe_target_url(target):
                return target
            return url
    except Exception:
        return url

def clean_url(raw: str, preserve_params: list | None = None, unshorten: bool = False) -> dict:
    preserve_set = {p.lower() for p in preserve_params} if preserve_params else set()
    res = {
        "is_valid": False,
        "original_url": (raw or "").strip(),
        "cleaned_url": "",
        "trackers_removed": [],
        "trackers_count": 0,
        "chars_saved": 0,
        "domain": "",
        "is_shortener": False,
        "message": ""
    }
    extracted = extract_url(raw)
    if not extracted:
        res["message"] = "No valid URL found in input"
        return res

    current = extracted
    if not re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*://", current, re.I):
        current = "https://" + current

    parsed_initial = urllib.parse.urlparse(current)
    initial_host = parsed_initial.netloc.lower()
    res["is_shortener"] = is_shortener_domain(initial_host)

    if unshorten and res["is_shortener"]:
        resolved = unshorten_url(current)
        if resolved != current:
            res["trackers_removed"].append("unshortened")
            current = resolved

    unwrapped, did_unwrap = unwrap_redirect(current)
    if did_unwrap:
        res["trackers_removed"].append("redirect_wrapper")
        current = unwrapped

    amazon_clean = normalize_amazon(current)
    if amazon_clean:
        res["is_valid"] = True
        res["original_url"] = extracted
        res["cleaned_url"] = amazon_clean
        res["domain"] = urllib.parse.urlparse(amazon_clean).netloc.lower()
        res["trackers_removed"].append("amazon_referrals")
        res["trackers_count"] = len(res["trackers_removed"])
        res["chars_saved"] = max(0, len(extracted) - len(amazon_clean))
        res["message"] = "Normalized Amazon product URL"
        return res

    yt_norm = normalize_youtube_shorts(current)
    if yt_norm:
        res["trackers_removed"].append("youtube_shorts")
        current = yt_norm

    parsed = urllib.parse.urlparse(current)
    hostname = parsed.netloc.lower()
    res["domain"] = hostname
    res["is_shortener"] = is_shortener_domain(hostname)

    # Parse query params preserving order
    query_parts = parsed.query.split("&") if parsed.query else []
    kept_parts = []
    removed = []

    for part in query_parts:
        if not part:
            continue
        key = part.split("=")[0]
        if is_tracking_param(key, hostname, preserve_set):
            try:
                removed.append(urllib.parse.unquote(key))
            except Exception:
                removed.append(key)
        else:
            kept_parts.append(part)

    fragment = parsed.fragment
    if fragment and (re.match(r"^(?:xtor|utm_)", fragment, re.I) or fragment.startswith(":~:text=")):
        removed.append("hash_tracker")
        fragment = ""

    cleaned_query = "&".join(kept_parts)
    cleaned = urllib.parse.urlunparse((
        parsed.scheme,
        parsed.netloc,
        parsed.path,
        parsed.params,
        cleaned_query,
        fragment
    ))

    res["is_valid"] = True
    res["original_url"] = extracted
    res["cleaned_url"] = cleaned
    res["trackers_removed"].extend(removed)
    res["trackers_count"] = len(res["trackers_removed"])
    res["chars_saved"] = max(0, len(extracted) - len(cleaned))
    res["message"] = f"Cleaned {res['trackers_count']} tracker{'s' if res['trackers_count'] > 1 else ''}" if res["trackers_count"] > 0 else "URL is clean"
    return res

def get_clipboard() -> str:
    try:
        proc = subprocess.run(["wl-paste", "--no-newline"], capture_output=True, text=True, check=True)
        return proc.stdout.strip()
    except Exception:
        return ""

def set_clipboard(text: str) -> bool:
    try:
        subprocess.run(["wl-copy"], input=text.encode("utf-8"), check=True)
        return True
    except Exception:
        return False

def open_in_browser(url: str):
    subprocess.Popen(["xdg-open", "--", url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def render_terminal_qr(text: str):
    try:
        subprocess.run(["qrencode", "-t", "ANSIUTF8", text])
    except Exception:
        print("Note: Install 'qrencode' package for ASCII terminal QR rendering.")

def main():
    parser = argparse.ArgumentParser(description="DeTrack — URL Tracker Cleaner & QR Code Generator")
    parser.add_argument("url", nargs="?", help="URL to clean")
    parser.add_argument("-c", "--clipboard", action="store_true", help="Read URL from clipboard, clean it, and copy back")
    parser.add_argument("-b", "--browse", action="store_true", help="Open cleaned URL in default web browser")
    parser.add_argument("-q", "--qr", action="store_true", help="Display QR code in terminal")
    parser.add_argument("-u", "--unshorten", action="store_true", help="Resolve and expand shortened URLs (bit.ly, t.co, etc.)")
    parser.add_argument("-p", "--preserve", nargs="*", help="Whitelist parameters to preserve (e.g. --preserve ref tag)")
    parser.add_argument("--json", action="store_true", help="Output JSON results")

    args = parser.parse_args()

    input_text = ""
    if args.clipboard:
        input_text = get_clipboard()
        if not input_text:
            print("Error: Clipboard is empty or could not be read.", file=sys.stderr)
            sys.exit(1)
    elif args.url:
        input_text = args.url
    elif not sys.stdin.isatty():
        input_text = sys.stdin.read().strip()
    else:
        input_text = get_clipboard()
        if not input_text:
            parser.print_help()
            sys.exit(0)

    res = clean_url(input_text, preserve_params=args.preserve, unshorten=args.unshorten)

    if args.json:
        print(json.dumps(res, indent=2))
        return

    if not res["is_valid"]:
        print(f"Error: {res['message']}", file=sys.stderr)
        sys.exit(1)

    if args.clipboard:
        set_clipboard(res["cleaned_url"])
        print(f"✓ Cleaned URL copied to clipboard: {res['cleaned_url']}")
        if res["trackers_count"] > 0:
            print(f"  Removed {res['trackers_count']} trackers: {', '.join(res['trackers_removed'])} (saved {res['chars_saved']} chars)")
    else:
        print(res["cleaned_url"])
        if res["trackers_count"] > 0:
            print(f"# Removed: {', '.join(res['trackers_removed'])}", file=sys.stderr)

    if args.qr:
        print("\nQR Code:")
        render_terminal_qr(res["cleaned_url"])

    if args.browse:
        open_in_browser(res["cleaned_url"])

if __name__ == "__main__":
    main()

