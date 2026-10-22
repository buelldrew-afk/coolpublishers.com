"""Write the latest Substack essays to data/substack.json for the homepage.

Runs on GitHub Actions before each deploy (see .github/workflows/deploy.yml).
If the feed can't be fetched, the existing file is left as it is.
"""
import json
import sys
import urllib.request
import xml.etree.ElementTree as ET
from email.utils import parsedate_to_datetime
from pathlib import Path

FEED = "https://drewbuell.substack.com/feed"
OUT = Path(__file__).resolve().parent.parent / "data" / "substack.json"
COUNT = 3


def main():
    try:
        req = urllib.request.Request(FEED, headers={"User-Agent": "coolpublishers.com feed updater"})
        with urllib.request.urlopen(req, timeout=30) as resp:
            root = ET.fromstring(resp.read())
    except Exception as e:
        print(f"Could not read the Substack feed ({e}); keeping {OUT.name} as it is.")
        return

    posts = []
    for item in root.iter("item"):
        image = ""
        for enc in item.findall("enclosure"):
            if enc.get("type", "").startswith("image/"):
                image = enc.get("url", "")
                break
        date = item.findtext("pubDate") or ""
        try:
            date = parsedate_to_datetime(date).isoformat()
        except (TypeError, ValueError):
            date = ""
        posts.append({
            "title": (item.findtext("title") or "").strip(),
            "subtitle": (item.findtext("description") or "").strip(),
            "link": (item.findtext("link") or "").strip(),
            "date": date,
            "image": image,
        })
        if len(posts) == COUNT:
            break

    if not posts:
        print("The feed had no posts; keeping the existing file.")
        return

    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text(json.dumps({"posts": posts}, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {len(posts)} posts to {OUT}")


if __name__ == "__main__":
    sys.exit(main())
