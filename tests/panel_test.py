"""Browser regression tests. Requires Playwright and its Chromium browser."""
from pathlib import Path
import sys
from playwright.sync_api import sync_playwright

root = Path(__file__).resolve().parent.parent
with sync_playwright() as p:
    browser = p.chromium.launch(headless=True, args=["--no-sandbox"])
    page = browser.new_page(viewport={"width": 400, "height": 560})
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.add_init_script("""
        window.messages = [];
        window.handlers = {};
        window.panel = {
            on: (name, fn) => { window.handlers[name] = fn; },
            post: (name, data) => { window.messages.push({name, data}); }
        };
    """)
    page.goto((root / "ui/panel.html").as_uri())
    assert page.evaluate("window.messages[0].name") == "ready"
    page.evaluate("window.handlers.update({players:[{name:'<img src=x onerror=alert(1)>',kills:2,pct:100,kills_per_hour:2}],total_kills:2,in_group:true,session_time:'1h',group_kph:2})")
    assert page.locator('.player-name').inner_text() == '<img src=x onerror=alert(1)>'
    assert page.locator('.player-name img').count() == 0
    for selector, message in [('btn-publish','publish'),('btn-save','save'),('btn-reset','reset'),('btn-group','group')]:
        page.locator('#'+selector).click()
        assert page.evaluate('window.messages.at(-1).name') == message
    assert page.evaluate('window.messages.at(-1).data.in_group') is False
    assert not errors, errors
    if len(sys.argv) > 1:
        page.screenshot(path=sys.argv[1])
    browser.close()
print("PASS: panel rendering and actions")
