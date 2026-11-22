"""GitHub Pages landing page (docs/index.html) for Corewords: SEO meta, Open Graph, JSON-LD, FAQ. Based on heyobi/querly scripts/landing-pages.py.
Usage: python -X utf8 scripts/landing-page.py"""
import html, json

BADGE = 'app-store-badge.svg'

CSS = """
:root{--bg:#fff;--fg:#14141a;--muted:#5b5b6b;--card:#f4f5f8;--line:#e3e5ec;--accent:#4f6bff}
@media (prefers-color-scheme:dark){:root{--bg:#0b0b10;--fg:#f2f2f6;--muted:#a4a4b4;--card:#16161e;--line:#262633;--accent:#7d93ff}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:17px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif}
main{max-width:1040px;margin:0 auto;padding:40px 16px 64px}
header{text-align:center}header img.icon{width:112px;height:112px;border-radius:24px;box-shadow:0 10px 30px rgba(0,0,0,.18)}
h1{font-size:clamp(30px,5vw,46px);line-height:1.15;margin:18px 0 10px;letter-spacing:-.02em}
.lead{font-size:clamp(17px,2.2vw,20px);color:var(--muted);max-width:720px;margin:0 auto 22px}
.badge img{height:54px}
.shots{display:flex;gap:14px;overflow-x:auto;padding:28px 0 8px;scroll-snap-type:x mandatory}
.shots img{height:min(560px,70vh);border-radius:18px;scroll-snap-align:center;flex:none;box-shadow:0 8px 24px rgba(0,0,0,.15)}
h2{font-size:28px;margin:48px 0 12px;letter-spacing:-.01em}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:14px}
.card{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:18px}
.card b{display:block;margin-bottom:4px}
details{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:14px 18px;margin:10px 0}
summary{font-weight:600;cursor:pointer}
a{color:var(--accent)}code{font:15px ui-monospace,Menlo,monospace;background:var(--card);padding:1px 6px;border-radius:6px}
.wide img{width:100%;border-radius:18px;box-shadow:0 8px 24px rgba(0,0,0,.15)}
footer{color:var(--muted);font-size:14px;margin-top:56px;text-align:center}
"""


def page(app):
    faq_ld = {"@context": "https://schema.org", "@type": "FAQPage", "mainEntity": [
        {"@type": "Question", "name": q, "acceptedAnswer": {"@type": "Answer", "text": a}} for q, a in app['faq']]}
    app_ld = {"@context": "https://schema.org", "@type": "SoftwareApplication", "name": app['name'],
              "operatingSystem": "iOS, iPadOS", "applicationCategory": app['category'],
              "description": app['description'], "url": app['store'], "downloadUrl": app['store'],
              "image": app['site'] + 'icon.png', "screenshot": [app['site'] + s for s, _ in app['shots']],
              "offers": {"@type": "Offer", "price": "0", "priceCurrency": "USD"},
              "author": {"@type": "Person", "name": "heyobi", "url": "https://github.com/heyobi"}}
    e = html.escape
    shots = '\n'.join(f'    <img src="{s}" alt="{e(alt)}" loading="lazy">' for s, alt in app['shots'])
    feats = '\n'.join(f'    <div class="card"><b>{e(t)}</b>{e(d)}</div>' for t, d in app['features'])
    faq = '\n'.join(f'  <details><summary>{e(q)}</summary><p>{e(a)}</p></details>' for q, a in app['faq'])
    extra = app.get('extra', '')
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{e(app['title'])}</title>
<meta name="description" content="{e(app['description'])}">
<meta name="keywords" content="{e(app['keywords'])}">
<link rel="canonical" href="{app['site']}">
<link rel="icon" href="icon.png">
<meta name="apple-itunes-app" content="app-id={app['id']}">
<meta property="og:type" content="website">
<meta property="og:title" content="{e(app['title'])}">
<meta property="og:description" content="{e(app['description'])}">
<meta property="og:url" content="{app['site']}">
<meta property="og:image" content="{app['site']}{app['shots'][0][0]}">
<meta name="twitter:card" content="summary_large_image">
<script type="application/ld+json">{json.dumps(app_ld, ensure_ascii=False)}</script>
<script type="application/ld+json">{json.dumps(faq_ld, ensure_ascii=False)}</script>
<style>{CSS}</style>
</head>
<body>
<main>
<header>
  <img class="icon" src="icon.png" alt="{e(app['name'])} app icon" width="112" height="112">
  <h1>{e(app['h1'])}</h1>
  <p class="lead">{e(app['lead'])}</p>
  <a class="badge" href="{app['store']}"><img src="{BADGE}" alt="Download {e(app['name'])} on the App Store"></a>
</header>
<div class="shots">
{shots}
</div>
<h2>{e(app['features_title'])}</h2>
<div class="grid">
{feats}
</div>
{extra}
<h2>Questions</h2>
{faq}
<footer>
  <p><a href="{app['store']}">{e(app['name'])} on the App Store</a> · <a href="{app['repo']}">Source code on GitHub</a> · {app['sibling']}</p>
  <p>{e(app['legal'])}</p>
</footer>
</main>
</body>
</html>
"""


FREE_PRO = """
<h2>Free and Pro</h2>
<div class="grid">
  <div class="card"><b>Free</b>The 2,858-word core deck (NGSL 1.2 plus days, months and numbers) with every exercise type, spaced repetition, all 18 grammar lessons, the 44-sound chart with audio, the placement test, daily goal, streak, reminders and progress.</div>
  <div class="card"><b>Pro, one-time purchase</b>The extended list (2,186 more words, to about 98% of everyday English), 205 phrasal verbs, the full minimal-pair trainer and the on-device &ldquo;Say it&rdquo; pronunciation check. No subscription, no ads.</div>
</div>
<h2>On iPad and iPhone Duo</h2>
<p>Today, Progress, lessons and every exercise use two columns on wide screens. On the open iPhone Duo the question sits on one side of the fold and the answers on the other.</p>
<div class="wide"><img src="screens/duo-3-gap.jpg" alt="Fill-the-gap exercise on the open iPhone Duo, question left of the fold and answers right" loading="lazy"></div>
<p></p>
<div class="wide"><img src="screens/ipad-5-progress.jpg" alt="Progress screen on iPad with coverage, streak and review forecast" loading="lazy" style="max-width:640px;display:block;margin:0 auto"></div>
<h2>Where the words come from</h2>
<p>The word lists and their order come from the <a href="https://www.newgeneralservicelist.com/new-general-service-list">New General Service List (NGSL) 1.2</a> and the <a href="https://www.newgeneralservicelist.com/ngsl-graded-reader">NGSL-GR</a> by Charles Browne, Brent Culligan and Joseph Phillips, licensed under <a href="https://creativecommons.org/licenses/by-sa/4.0/">CC BY-SA 4.0</a>. American IPA is converted from the <a href="https://github.com/cmusphinx/cmudict">CMU Pronouncing Dictionary</a> and British IPA comes from <a href="https://github.com/JoseLlarena/Britfone">Britfone</a>. Definitions, example sentences, Turkish translations, lessons and the phrasal verb selection were written for Corewords; the whole data set is <a href="https://github.com/heyobi/corewords/tree/main/content">on GitHub under CC BY-SA 4.0</a>.</p>
"""

corewords_app = dict(
    id='6837889401', name='Corewords', category='EducationalApplication',
    store='https://apps.apple.com/app/id6837889401',
    site='https://heyobi.github.io/corewords/', repo='https://github.com/heyobi/corewords',
    title='Corewords: learn the most common English words | NGSL vocabulary app with IPA and phrasal verbs',
    h1='Learn the most common English words first',
    lead='Corewords teaches the 2,800 words that cover about 92% of everyday English, in frequency order, with spaced repetition, American and British pronunciation in IPA, phrasal verbs and short grammar lessons. Native app for iPhone, iPad and iPhone Duo. Offline, no account, no ads.',
    description='English vocabulary app for iPhone and iPad: the NGSL word list (2,800 most common words, 92% of everyday English) and 5,000 words with spaced repetition, US and UK IPA pronunciation, phrasal verbs, grammar lessons and a minimal-pair trainer. Offline, no ads.',
    keywords='most common English words app, NGSL word list app, New General Service List app, English vocabulary app iPhone, phrasal verbs app, English pronunciation IPA app, spaced repetition English words, learn English words offline, minimal pairs app, İngilizce kelime uygulaması',
    shots=[('screens/iphone-1-today.jpg', 'Today screen with reviews, new words, daily goal and coverage of everyday English'),
           ('screens/iphone-2-intro.jpg', 'New word card with US and UK IPA, audio, definition and example'),
           ('screens/iphone-3-gap.jpg', 'Fill-the-gap exercise with feedback'),
           ('screens/iphone-4-listen.jpg', 'Listening exercise: which word do you hear?'),
           ('screens/iphone-5-progress.jpg', 'Progress: coverage, streak, activity and review forecast'),
           ('screens/iphone-6-sounds.jpg', 'The 44 sounds of English with minimal pairs'),
           ('screens/iphone-7-lessons.jpg', 'Grammar lessons for the most frequent function words')],
    features_title='Built to make words stick',
    features=[('Frequency order', 'Start with the words you will meet most: the NGSL core list covers about 92% of the words in everyday English text, the extended list about 98%.'),
              ('Spaced repetition', 'An SM-2 scheduler brings each word back just before you would forget it, with short learning steps for new words.'),
              ('Six kinds of exercise', 'Word to meaning, meaning to word, listen and choose, fill the gap, type the word, and say it out loud with on-device speech recognition.'),
              ('US and UK pronunciation', 'IPA for both accents with stress marks, played by the voices built into iOS, at normal or slow speed.'),
              ('Placement test', 'About 40 questions find the words you already know, so you start at your level instead of at zero.'),
              ('Phrasal verbs', '205 everyday phrasal verbs such as get up, look after and put up with, with separable and inseparable notes.'),
              ('Grammar for small words', '18 lessons on a/an, the, in/on/at, to/for, will and going to, modals, some/any and more, each with a quiz.'),
              ('For Turkish speakers too', 'Optional Turkish translations and tips for the sounds Turkish speakers find hardest: th, v/w, long and short vowels, schwa.')],
    faq=[('How do I learn the most common English words?', 'Learn them in frequency order and review them with spaced repetition. Corewords starts with the most frequent words of the New General Service List and schedules each review just before you would forget the word, so a few minutes a day add up to thousands of words.'),
         ('Is there an NGSL word list app?', 'Yes. Corewords is built on the New General Service List (NGSL 1.2, 2,809 words) and the NGSL-GR extension to 5,000 words, with definitions, example sentences, IPA and audio for every word.'),
         ('How many English words do I need to know?', 'About 2,800 well-chosen words cover roughly 92% of the words in everyday English text, and about 5,000 cover around 98%. Corewords shows the share of everyday English your known words cover.'),
         ('Is there a good app for phrasal verbs?', 'Corewords includes 205 frequent phrasal verbs (get up, look after, figure out, put up with and more) with meanings, examples and spaced-repetition practice, including fill-the-gap and typing exercises.'),
         ('How can I learn English pronunciation with IPA?', 'Every word in Corewords shows its IPA transcription for American and British English with a play button for each accent. The Sounds tab explains all 44 English sounds and trains your ear with minimal pairs like sheep/ship and three/tree.'),
         ('Does Corewords work offline and without an account?', 'Yes. All words, lessons and audio work offline, there is no account and no ads, and your progress stays on your device.'),
         ('Does Corewords have Turkish translations?', 'Yes. Every word has a Turkish translation (İngilizce kelime ve Türkçe anlamı) that you can show or hide; definitions are always available in simple English.'),
         ('Is Corewords free?', 'The 2,858-word core deck with all exercises, lessons, the sound chart and the placement test is free. A one-time Pro purchase adds the extended list, phrasal verbs, the full minimal-pair trainer and Say it.')],
    extra=FREE_PRO,
    sibling='Also by the same developer: <a href="https://heyobi.github.io/querly/">Querly: open CSV and Excel files on iPhone</a> · <a href="https://heyobi.github.io/pgnotebook/">Tuple: run PostgreSQL on iPhone</a>',
    legal='Word lists: NGSL 1.2 and NGSL-GR by Browne, Culligan and Phillips, CC BY-SA 4.0. Corewords is not affiliated with the NGSL project.',
)

open('docs/index.html', 'w', encoding='utf-8', newline='\n').write(page(corewords_app))
print('docs/index.html written')

