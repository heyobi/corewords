# Writes store/listing.json (App Store name, subtitle, keywords, promo text, description) for 5 locales and checks Apple's limits.
# Usage: python -X utf8 scripts/listing.py
import json
import os

L = {}

L['en-US'] = dict(
    name='Corewords: English Vocabulary',
    subtitle='Phrasal Verbs & Pronunciation',
    keywords='words,learn,flashcards,ipa,phonetics,spaced repetition,ngsl,common,frequency,esl,ielts,toefl,grammar',
    promo='Learn the 2,800 words that cover 92% of everyday English first. Spaced repetition, US and UK pronunciation with IPA, phrasal verbs. Offline, no account, no ads.',
    description="""Learn the English words you'll actually meet, the most useful ones first.

Corewords teaches English vocabulary in frequency order. The core deck is the New General Service List (NGSL): 2,800 words that cover about 92% of the words in everyday English text. Learn them and most of what you read and hear is made of words you know. Then go on to 5,000 words, about 98%.

EVERY WORD, PROPERLY
• A short definition in simple English and a natural example sentence
• IPA for American and British English, with audio for both accents
• Word forms (go, goes, went, gone) and its frequency rank
• Turkish translations for Turkish speakers

SPACED REPETITION THAT TEACHES
Each word comes back just before you would forget it. Exercises move from recognizing a word to producing it:
• Word → meaning and meaning → word
• Listen and choose
• Fill the gap in a sentence
• Type the word
• Say it: on-device speech recognition checks your pronunciation

START AT YOUR LEVEL
A 3-minute placement test finds the words you already know, so you don't start from zero. Set a daily pace, keep a streak, get a reminder, and watch your coverage grow: "the words you know cover 74% of everyday English."

PHRASAL VERBS
205 everyday phrasal verbs, from get up and look after to put up with, with notes on which ones can be separated.

THE SMALL WORDS THAT MATTER MOST
The, of, to, in, a and for make up a huge share of every text. 18 short lessons explain articles (a, an, the, no article), in/on/at for place and time, to/for, will and going to, would, can/could/may/might, must and should, some and any, and more, each with a quiz.

PRONUNCIATION
All 44 sounds of English with tips, and a minimal-pair trainer to hear the difference: sheep or ship, three or tree, vet or wet.

MADE FOR EVERY SCREEN
Native app for iPhone, iPad and iPhone Duo, with layouts that use the extra space.

PRIVATE AND OFFLINE
No account, no ads, no tracking. Everything stays on your device and works without internet.

FREE AND PRO
Free: the 2,800-word core deck with every exercise, all grammar lessons, the 44-sound chart, the placement test and progress. A one-time Pro purchase adds the extended list (2,200 more words), phrasal verbs, the full minimal-pair trainer and Say it. No subscription.

Word lists: NGSL 1.2 and NGSL-GR by Browne, Culligan and Phillips, CC BY-SA 4.0. Pronunciation data: CMU Pronouncing Dictionary and Britfone. Definitions and examples were written for Corewords.""")

L['tr'] = dict(
    name='Corewords: İngilizce Kelime',
    subtitle='Phrasal Verb, Telaffuz ve IPA',
    keywords='öğren,ezber,kart,fonetik,sıklık,tekrar,dilbilgisi,yds,ielts,toefl,vocabulary,english,words,ngsl',
    promo='Günlük İngilizcenin %92\'sini karşılayan 2.800 kelimeyi önce öğrenin. Aralıklı tekrar, ABD ve İngiliz telaffuzu, IPA, Türkçe karşılıklar. İnternetsiz, reklamsız.',
    description="""Gerçekten karşılaşacağınız İngilizce kelimeleri, en faydalısından başlayarak öğrenin.

Corewords İngilizce kelimeleri kullanım sıklığına göre öğretir. Temel deste New General Service List'tir (NGSL): günlük İngilizce metinlerdeki kelimelerin yaklaşık %92'sini karşılayan 2.800 kelime. Bunları öğrendiğinizde okuduğunuz ve duyduğunuz şeylerin çoğu bildiğiniz kelimelerden oluşur. Sonra 5.000 kelimeye, yani yaklaşık %98'e çıkın.

HER KELİME EKSİKSİZ
• Türkçe karşılık
• Basit İngilizce tanım ve doğal bir örnek cümle
• Amerikan ve İngiliz İngilizcesi için IPA ve iki aksanda ses
• Kelime biçimleri (go, goes, went, gone) ve sıklık sırası

ÖĞRETEN ARALIKLI TEKRAR
Her kelime tam unutmak üzereyken karşınıza gelir. Alıştırmalar tanımaktan üretmeye doğru ilerler:
• Kelime → anlam ve anlam → kelime
• Dinle ve seç
• Cümledeki boşluğu doldur
• Kelimeyi yaz
• Söyle: cihaz üzerinde konuşma tanıma telaffuzunuzu kontrol eder

SEVİYENİZDEN BAŞLAYIN
3 dakikalık seviye testi bildiğiniz kelimeleri bulur, sıfırdan başlamazsınız. Günlük temponuzu seçin, serinizi sürdürün, hatırlatıcı alın ve kapsamanızın büyümesini izleyin: "bildiğiniz kelimeler günlük İngilizcenin %74'ünü karşılıyor."

PHRASAL VERB'LER
get up, look after, put up with gibi 205 günlük phrasal verb; hangilerinin ayrılabildiğine dair notlarla.

EN ÇOK İŞE YARAYAN KÜÇÜK KELİMELER
The, of, to, in, a, for her metnin büyük bir bölümünü oluşturur. 18 kısa ders; tanımlıklar (a, an, the, tanımlıksız kullanım), yer ve zaman için in/on/at, to/for, will ve going to, would, can/could/may/might, must ve should, some ve any gibi konuları Türkçe notlarla anlatır; her ders bir testle biter.

TELAFFUZ
İngilizcenin 44 sesi ve Türkçe konuşanlar için ipuçları (th, v/w, uzun ve kısa ünlüler, schwa). Farkı duymak için minimal çift çalışması: sheep mi ship mi, three mü tree mi, vet mi wet mi?

HER EKRAN İÇİN
iPhone, iPad ve iPhone Duo için yerel uygulama; geniş ekranı iyi kullanan yerleşimler.

GİZLİ VE İNTERNETSİZ
Hesap yok, reklam yok, izleme yok. Her şey cihazınızda kalır ve internetsiz çalışır.

ÜCRETSİZ VE PRO
Ücretsiz: tüm alıştırmalarıyla 2.800 kelimelik temel deste, tüm dil bilgisi dersleri, 44 sesli tablo, seviye testi ve ilerleme. Tek seferlik Pro satın alma; genişletilmiş listeyi (2.200 kelime daha), phrasal verb'leri, minimal çiftlerin tamamını ve Söyle alıştırmasını ekler. Abonelik yok.

Kelime listeleri: Browne, Culligan ve Phillips'in NGSL 1.2 ve NGSL-GR listeleri, CC BY-SA 4.0. Telaffuz verisi: CMU Pronouncing Dictionary ve Britfone. Tanımlar, örnekler ve Türkçe karşılıklar Corewords için yazıldı.""")

L['es-MX'] = dict(
    name='Corewords: Vocabulario Inglés',
    subtitle='Phrasal verbs y pronunciación',
    keywords='english,palabras,aprender,tarjetas,ipa,fonética,repetición espaciada,frecuentes,gramática,toefl',
    promo='Aprende primero las 2,800 palabras que cubren el 92% del inglés cotidiano. Repetición espaciada, pronunciación de EE. UU. y Reino Unido con IPA. Sin conexión ni anuncios.',
    description="""Aprende las palabras en inglés que de verdad vas a encontrar, empezando por las más útiles.

Corewords enseña vocabulario en inglés por orden de frecuencia. El mazo principal es la New General Service List (NGSL): 2,800 palabras que cubren cerca del 92% de las palabras de un texto cotidiano en inglés. Después puedes llegar a 5,000 palabras, cerca del 98%.

CADA PALABRA, COMPLETA
• Una definición breve en inglés sencillo y una oración de ejemplo natural
• IPA para inglés estadounidense y británico, con audio de ambos acentos
• Formas de la palabra (go, goes, went, gone) y su puesto de frecuencia
(Las definiciones están en inglés sencillo; las traducciones incluidas son al turco.)

REPETICIÓN ESPACIADA QUE ENSEÑA
Cada palabra vuelve justo antes de que la olvides. Los ejercicios van de reconocer a producir: palabra → significado, significado → palabra, escuchar y elegir, completar la oración, escribir la palabra y Dilo: el reconocimiento de voz en el dispositivo revisa tu pronunciación.

EMPIEZA EN TU NIVEL
Una prueba de nivel de 3 minutos encuentra las palabras que ya conoces. Meta diaria, racha, recordatorios y tu cobertura del inglés cotidiano.

PHRASAL VERBS, GRAMÁTICA Y SONIDOS
205 phrasal verbs comunes, 18 lecciones breves sobre las palabras más pequeñas y frecuentes (a, an, the, in, on, at, to, for…), los 44 sonidos del inglés y un entrenador de pares mínimos (sheep/ship, three/tree).

PARA iPhone, iPad Y iPhone Duo. Sin cuenta, sin anuncios, sin rastreo, sin conexión.

GRATIS Y PRO
Gratis: el mazo principal de 2,800 palabras con todos los ejercicios, las lecciones, la tabla de sonidos, la prueba de nivel y el progreso. Una compra única de Pro añade la lista ampliada, los phrasal verbs, todos los pares mínimos y Dilo. Sin suscripción.

Listas: NGSL 1.2 y NGSL-GR (Browne, Culligan y Phillips), CC BY-SA 4.0. Pronunciación: CMU Pronouncing Dictionary y Britfone.""")

L['pt-BR'] = dict(
    name='Corewords: Vocabulário Inglês',
    subtitle='Phrasal verbs e pronúncia',
    keywords='english,palavras,aprender,flashcards,ipa,fonética,repetição espaçada,frequentes,gramática,toefl',
    promo='Aprenda primeiro as 2.800 palavras que cobrem 92% do inglês do dia a dia. Repetição espaçada, pronúncia americana e britânica com IPA. Offline, sem anúncios.',
    description="""Aprenda as palavras em inglês que você vai realmente encontrar, começando pelas mais úteis.

O Corewords ensina vocabulário em inglês por ordem de frequência. O baralho principal é a New General Service List (NGSL): 2.800 palavras que cobrem cerca de 92% das palavras de um texto comum em inglês. Depois, avance até 5.000 palavras, cerca de 98%.

CADA PALAVRA, COMPLETA
• Uma definição curta em inglês simples e uma frase de exemplo natural
• IPA do inglês americano e britânico, com áudio dos dois sotaques
• Formas da palavra (go, goes, went, gone) e posição de frequência
(As definições são em inglês simples; as traduções incluídas são para o turco.)

REPETIÇÃO ESPAÇADA QUE ENSINA
Cada palavra volta pouco antes de você esquecer. Os exercícios vão de reconhecer a produzir: palavra → significado, significado → palavra, ouvir e escolher, completar a frase, digitar a palavra e Fale: o reconhecimento de voz no próprio aparelho confere sua pronúncia.

COMECE NO SEU NÍVEL
Um teste de nivelamento de 3 minutos encontra as palavras que você já conhece. Meta diária, sequência, lembretes e sua cobertura do inglês do dia a dia.

PHRASAL VERBS, GRAMÁTICA E SONS
205 phrasal verbs comuns, 18 lições curtas sobre as palavras pequenas e frequentes (a, an, the, in, on, at, to, for…), os 44 sons do inglês e um treino de pares mínimos (sheep/ship, three/tree).

PARA iPhone, iPad E iPhone Duo. Sem conta, sem anúncios, sem rastreamento, funciona offline.

GRÁTIS E PRO
Grátis: o baralho principal de 2.800 palavras com todos os exercícios, as lições, a tabela de sons, o teste de nível e o progresso. Uma compra única do Pro adiciona a lista estendida, os phrasal verbs, todos os pares mínimos e Fale. Sem assinatura.

Listas: NGSL 1.2 e NGSL-GR (Browne, Culligan e Phillips), CC BY-SA 4.0. Pronúncia: CMU Pronouncing Dictionary e Britfone.""")

L['de-DE'] = dict(
    name='Corewords: Englisch Vokabeln',
    subtitle='Phrasal Verbs & Aussprache',
    keywords='english,wörter,lernen,karteikarten,ipa,phonetik,wortschatz,häufigste,grammatik,toefl,ielts',
    promo='Lerne zuerst die 2.800 Wörter, die 92 % des Alltagsenglisch abdecken. Spaced Repetition, amerikanische und britische Aussprache mit IPA. Offline, ohne Werbung.',
    description="""Lerne die englischen Wörter, die dir wirklich begegnen, die nützlichsten zuerst.

Corewords bringt dir englischen Wortschatz nach Häufigkeit bei. Das Grunddeck ist die New General Service List (NGSL): 2.800 Wörter, die etwa 92 % der Wörter in alltäglichen englischen Texten abdecken. Danach geht es weiter bis 5.000 Wörter, etwa 98 %.

JEDES WORT VOLLSTÄNDIG
• Eine kurze Definition in einfachem Englisch und ein natürlicher Beispielsatz
• IPA für amerikanisches und britisches Englisch, mit Audio für beide Akzente
• Wortformen (go, goes, went, gone) und Häufigkeitsrang
(Die Definitionen sind in einfachem Englisch; die enthaltenen Übersetzungen sind türkisch.)

SPACED REPETITION, DIE LEHRT
Jedes Wort kommt zurück, kurz bevor du es vergisst. Die Übungen gehen vom Erkennen zum Anwenden: Wort → Bedeutung, Bedeutung → Wort, Hören und Wählen, Lückentext, Wort tippen und Sag es: Spracherkennung auf dem Gerät prüft deine Aussprache.

STARTE AUF DEINEM NIVEAU
Ein 3-minütiger Einstufungstest findet die Wörter, die du schon kennst. Tagesziel, Serie, Erinnerungen und deine Abdeckung des Alltagsenglisch.

PHRASAL VERBS, GRAMMATIK UND LAUTE
205 häufige Phrasal Verbs, 18 kurze Lektionen zu den kleinen, häufigen Wörtern (a, an, the, in, on, at, to, for …), die 44 Laute des Englischen und ein Minimalpaar-Training (sheep/ship, three/tree).

FÜR iPhone, iPad UND iPhone Duo. Kein Konto, keine Werbung, kein Tracking, funktioniert offline.

KOSTENLOS UND PRO
Kostenlos: das Grunddeck mit 2.800 Wörtern und allen Übungen, alle Lektionen, die Lauttabelle, der Einstufungstest und der Fortschritt. Ein einmaliger Pro-Kauf ergänzt die erweiterte Liste, die Phrasal Verbs, alle Minimalpaare und Sag es. Kein Abo.

Wortlisten: NGSL 1.2 und NGSL-GR (Browne, Culligan und Phillips), CC BY-SA 4.0. Aussprache: CMU Pronouncing Dictionary und Britfone.""")

LIMITS = dict(name=30, subtitle=30, keywords=100, promo=170, description=4000)
ok = True
for loc, d in L.items():
    for k, n in LIMITS.items():
        if len(d[k]) > n:
            ok = False
            print(f'{loc} {k} too long: {len(d[k])} > {n}')
os.makedirs('store', exist_ok=True)
json.dump(L, open('store/listing.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
print('ok' if ok else 'FIX LIMITS', {loc: {k: len(v) for k, v in d.items() if k != 'description'} for loc, d in L.items()})
