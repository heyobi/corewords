# Builds Corewords/Localizable.xcstrings (English source, Turkish translations) and lists UI literals with no
# translation. Interpolated strings use their format keys (%lld for Int, %@ for String).
# Usage: python -X utf8 scripts/strings.py
import glob
import json
import re

TR = {
    # Tabs
    'Today': 'Bugün', 'Words': 'Kelimeler', 'Lessons': 'Dersler', 'Sounds': 'Sesler', 'Progress': 'İlerleme',
    'Settings': 'Ayarlar',
    # Today
    'Good morning': 'Günaydın', 'Good afternoon': 'İyi günler', 'Good evening': 'İyi akşamlar',
    'to review': 'tekrar', 'new words': 'yeni kelime',
    "Start today's session": 'Bugünün dersine başla',
    'All done for today': 'Bugünlük bu kadar',
    'Come back tomorrow for your reviews, or learn a few more words now.': 'Tekrarlar için yarın gelin ya da şimdi birkaç kelime daha öğrenin.',
    'Learn 5 more words': '5 kelime daha öğren',
    '%lld-day streak': '%lld günlük seri',
    'Daily goal': 'Günlük hedef',
    '%lld of %lld exercises': '%2$lld alıştırmadan %1$lld',
    '%lld%% correct today': 'Bugün %%%lld doğru',
    'Everyday English you can read': 'Okuyabildiğiniz günlük İngilizce',
    '%lld%%': '%%%lld',
    'The %lld words you know cover about %lld%% of the words in everyday English text.': 'Bildiğiniz %1$lld kelime, günlük İngilizce metinlerdeki kelimelerin yaklaşık %%%2$lld kadarını karşılıyor.',
    'Not a beginner?': 'Yeni başlayan değil misiniz?',
    'Take a 3-minute test and skip the words you already know.': '3 dakikalık testi çözün, bildiğiniz kelimeleri atlayın.',
    'Start': 'Başla',
    'Your decks': 'Desteleriniz',
    'Core 2,800': 'Temel 2.800',
    'The NGSL: the most frequent words, about 92% of everyday English.': 'NGSL: en sık kullanılan kelimeler, günlük İngilizcenin yaklaşık %92\'si.',
    'Extended 5,000': 'Genişletilmiş 5.000',
    '2,200 more words for reading news, books and work email.': 'Haber, kitap ve iş e-postası okumak için 2.200 kelime daha.',
    'Phrasal verbs': 'Phrasal verb\'ler',
    '205 everyday phrasal verbs like get up, look after, put up with.': 'get up, look after, put up with gibi 205 günlük phrasal verb.',
    '%lld of %lld learned': '%2$lld kelimeden %1$lld öğrenildi',
    'Tap to include or leave out this deck in your daily session': 'Bu desteyi günlük derse eklemek ya da çıkarmak için dokunun',
    # Session
    'Close': 'Kapat', '%lld left': '%lld kaldı',
    'New word': 'Yeni kelime', 'What does it mean?': 'Anlamı ne?', 'Which word means this?': 'Hangi kelime bu anlama gelir?',
    'Which word do you hear?': 'Hangi kelimeyi duyuyorsunuz?', 'Fill the gap': 'Boşluğu doldurun',
    'Type the missing word': 'Eksik kelimeyi yazın', 'Say it out loud': 'Sesli söyleyin',
    "I don't know": 'Bilmiyorum',
    'Got it, practice it': 'Anladım, alıştırma yapalım',
    'I already know this word': 'Bu kelimeyi zaten biliyorum',
    'Forms: %@': 'Biçimler: %@',
    'Type here': 'Buraya yazın', 'Hint': 'İpucu', 'Check': 'Kontrol et', 'Show the answer': 'Cevabı göster',
    'Corewords needs microphone and speech recognition permission for this exercise. You can allow it in Settings.':
        'Bu alıştırma için Corewords\'ün mikrofon ve konuşma tanıma iznine ihtiyacı var. Ayarlar\'dan izin verebilirsiniz.',
    "On-device speech recognition isn't available on this iPhone right now.": 'Cihaz üzerinde konuşma tanıma bu iPhone\'da şu anda kullanılamıyor.',
    'Type it instead': 'Bunun yerine yazın',
    'Hold to speak': 'Konuşmak için basılı tutun',
    'Listening…': 'Dinleniyor…',
    'Hold the button and say the word': 'Düğmeye basılı tutun ve kelimeyi söyleyin',
    "I can't speak now": 'Şu an konuşamıyorum',
    'We heard: "%@"': 'Duyduğumuz: "%@"',
    'Almost! Watch the spelling.': 'Neredeyse! Yazılışa dikkat.',
    'Correct!': 'Doğru!', 'Not quite': 'Tam değil',
    'You wrote: %@': 'Yazdığınız: %@',
    'Continue': 'Devam',
    'Session complete': 'Ders tamamlandı',
    'Nothing to study right now': 'Şu anda çalışılacak bir şey yok',
    'exercises': 'alıştırma', 'correct': 'doğru', 'day streak': 'günlük seri',
    'You now know %lld words, about %lld%% of everyday English.': 'Artık %1$lld kelime biliyorsunuz; bu, günlük İngilizcenin yaklaşık %%%2$lld kadarı.',
    'Your reviews are scheduled for later. Come back tomorrow, or add more decks.': 'Tekrarlarınız ileri bir zamana planlandı. Yarın gelin ya da başka desteler ekleyin.',
    'Done': 'Bitti',
    'Play': 'Dinle', 'Play slowly': 'Yavaş dinle',
    # Words
    'All': 'Tümü', 'Learning': 'Öğreniliyor', 'Learned': 'Öğrenildi', 'New': 'Yeni',
    'Search English or Turkish': 'İngilizce ya da Türkçe arayın',
    'Pick a word': 'Bir kelime seçin',
    'Every word has US and UK pronunciation, a meaning and an example.': 'Her kelimenin ABD ve İngiltere telaffuzu, anlamı ve örneği var.',
    'Deck': 'Deste', 'Core': 'Temel', 'Extended': 'Genişletilmiş', 'Phrasal': 'Phrasal', 'Show': 'Göster',
    'Browse freely. Studying this deck is part of Pro.': 'Serbestçe göz atın. Bu desteyle çalışmak Pro\'ya dahil.',
    '%lld words': '%lld kelime',
    'Example': 'Örnek', 'Word forms': 'Kelime biçimleri', 'Frequency': 'Sıklık',
    '#%lld of the most common English words': 'En sık kullanılan İngilizce kelimeler arasında %lld. sırada',
    'Knowing the top %lld words covers about %lld%% of everyday English.': 'En sık %1$lld kelimeyi bilmek, günlük İngilizcenin yaklaşık %%%2$lld kadarını karşılar.',
    'Your progress': 'İlerlemeniz',
    '%lld right, %lld wrong': '%1$lld doğru, %2$lld yanlış',
    'I know this word': 'Bu kelimeyi biliyorum', 'Reset': 'Sıfırla',
    'Not studied yet': 'Henüz çalışılmadı', 'Marked as known': 'Biliniyor olarak işaretlendi',
    'Learned · next review in %lld days (interval %lld days)': 'Öğrenildi · sonraki tekrar %1$lld gün sonra (aralık %2$lld gün)',
    'noun': 'isim', 'verb': 'fiil', 'adjective': 'sıfat', 'adverb': 'zarf', 'preposition': 'edat', 'pronoun': 'zamir',
    'determiner': 'belirleyici', 'conjunction': 'bağlaç', 'number': 'sayı', 'modal verb': 'yardımcı fiil',
    'interjection': 'ünlem', 'phrasal verb': 'phrasal verb', 'word': 'kelime',
    # Lessons
    'Small words, big difference': 'Küçük kelimeler, büyük fark',
    'The 50 most common English words are mostly function words like the, of, to and in. They make up about half of every text. Each lesson ends with a short quiz.':
        'En sık kullanılan 50 İngilizce kelimenin çoğu the, of, to, in gibi işlev kelimeleridir ve her metnin yaklaşık yarısını oluşturur. Her ders kısa bir testle biter.',
    'Quiz': 'Test',
    '%lld of %lld correct': '%2$lld sorudan %1$lld doğru',
    'Try again': 'Tekrar dene',
    'Verb + particle combinations with a new meaning: get up, look after, put up with. These 205 are among the most frequent in everyday English.':
        'Yeni bir anlam kazanan fiil + edat birleşimleri: get up, look after, put up with. Bu 205 tanesi günlük İngilizcede en sık kullanılanlar arasında.',
    'Study phrasal verbs': 'Phrasal verb çalış',
    'Show fewer': 'Daha az göster', 'Show all %lld': 'Tümünü göster (%lld)',
    'separable': 'ayrılabilir', 'inseparable': 'ayrılamaz', 'no object': 'nesnesiz',
    # Sounds
    'Hard for Turkish speakers': 'Türkçe konuşanlar için zor',
    "Sounds Turkish doesn't have, or uses differently": 'Türkçede olmayan ya da farklı kullanılan sesler',
    'Vowels': 'Ünlüler', 'Diphthongs': 'Çift ünlüler', 'Consonants': 'Ünsüzler',
    'Transcriptions follow standard dictionary IPA. US forms come from the CMU Pronouncing Dictionary, UK forms from Britfone.':
        'Okunuşlar standart sözlük IPA\'sını izler. ABD biçimleri CMU Pronouncing Dictionary\'den, İngiltere biçimleri Britfone\'dan gelir.',
    'Minimal pairs': 'Minimal çiftler',
    'sheep or ship? three or tree? Train your ear on %lld word pairs.': 'sheep mi ship mi? three mü tree mi? %lld kelime çiftiyle kulağınızı eğitin.',
    'Examples': 'Örnekler', 'vs': 'ya da',
    'Listen and choose the word you hear. Tap a word afterwards to compare.': 'Dinleyin ve duyduğunuz kelimeyi seçin. Sonra karşılaştırmak için kelimelere dokunun.',
    'Play again': 'Tekrar dinle', 'Next pair': 'Sonraki çift',
    # Progress
    'Basics: days, months, numbers': 'Temeller: günler, aylar, sayılar',
    'Top 500': 'İlk 500', '501–1,000': '501–1.000', '1,001–2,000': '1.001–2.000', '2,001–2,809': '2.001–2.809',
    'Extended 2,810–5,000': 'Genişletilmiş 2.810–5.000',
    'coverage': 'kapsama',
    '%lld words known': '%lld kelime biliniyor',
    'Words are ordered by how often they appear. The words you know cover about %lld%% of the words in everyday English text.':
        'Kelimeler kullanım sıklığına göre sıralanır. Bildiğiniz kelimeler, günlük İngilizce metinlerdeki kelimelerin yaklaşık %%%lld kadarını karşılıyor.',
    'Next milestone: %lld%%': 'Sonraki hedef: %%%lld',
    'You know the words in 95% of everyday English!': 'Günlük İngilizcenin %95\'indeki kelimeleri biliyorsunuz!',
    'best streak': 'en uzun seri', 'minutes': 'dakika',
    'Last 14 days': 'Son 14 gün', 'Reviews coming up': 'Yaklaşan tekrarlar', 'By frequency': 'Sıklığa göre',
    'Day': 'Gün', 'Exercises': 'Alıştırma', 'Goal': 'Hedef', 'Reviews': 'Tekrar',
    # Settings
    'New words per day': 'Günlük yeni kelime', 'Daily goal (exercises)': 'Günlük hedef (alıştırma)', 'Daily study': 'Günlük çalışma',
    '10 new words a day is about 3,600 a year. Reviews come on top and are what make words stick.':
        'Günde 10 yeni kelime yılda yaklaşık 3.600 eder. Tekrarlar bunun üstüne gelir ve kelimeleri kalıcı yapan da onlardır.',
    'Meaning and pronunciation': 'Anlam ve telaffuz',
    'Show meanings in': 'Anlam dili', 'Turkish + English': 'Türkçe + İngilizce', 'English only': 'Yalnızca İngilizce',
    'Accent': 'Aksan', 'American (US)': 'Amerikan (ABD)', 'British (UK)': 'İngiliz (Birleşik Krallık)',
    'Speaking speed': 'Konuşma hızı', 'Test the voice': 'Sesi dene',
    'Play words automatically': 'Kelimeleri otomatik seslendir',
    'Tip: for a more natural voice, download an Enhanced or Premium English voice in iOS Settings › Accessibility › Spoken Content › Voices.':
        'İpucu: daha doğal bir ses için iOS Ayarlar › Erişilebilirlik › Seslendirilen İçerik › Sesler bölümünden Gelişmiş ya da Premium bir İngilizce ses indirin.',
    '"Say it" exercises': '"Söyle" alıştırmaları',
    'Speech is recognized on your iPhone only. Nothing is recorded or uploaded.': 'Konuşma yalnızca iPhone\'unuzda tanınır. Hiçbir şey kaydedilmez ya da yüklenmez.',
    'Reminders': 'Hatırlatıcılar', 'Daily reminder': 'Günlük hatırlatıcı', 'Time': 'Saat',
    'Feedback': 'Geri bildirim', 'Sound': 'Ses', 'Haptics': 'Titreşim',
    'Corewords Pro': 'Corewords Pro', 'Pro is unlocked. Thank you!': 'Pro açıldı. Teşekkürler!', 'Unlock Pro': 'Pro\'yu aç',
    'Restore purchase': 'Satın alımı geri yükle',
    'Level': 'Seviye', 'Take the placement test again': 'Seviye testini yeniden çöz', 'Reset all progress': 'Tüm ilerlemeyi sıfırla',
    'About': 'Hakkında', 'Sources and licenses': 'Kaynaklar ve lisanslar', 'Privacy: no data is collected': 'Gizlilik: hiçbir veri toplanmaz',
    'Version': 'Sürüm',
    'Reset all progress?': 'Tüm ilerleme sıfırlansın mı?', 'Cancel': 'Vazgeç', 'OK': 'Tamam',
    "Every word goes back to new and your streak starts again. This can't be undone.": 'Tüm kelimeler yeniye döner ve seriniz baştan başlar. Bu geri alınamaz.',
    'Word lists': 'Kelime listeleri', 'Pronunciation': 'Telaffuz', 'Meanings and examples': 'Anlamlar ve örnekler', 'App': 'Uygulama',
    'Word order and frequency bands come from these lists. Coverage figures are approximate.': 'Kelime sırası ve sıklık bantları bu listelerden gelir. Kapsama oranları yaklaşıktır.',
    'Audio is spoken by the voices built into iOS. No recordings are included.': 'Sesler iOS\'un yerleşik sesleriyle okunur. Kayıtlı ses dosyası yoktur.',
    'Definitions, example sentences, Turkish translations, lessons and phrasal verb selections were written for Corewords. Together with the word lists they are shared under CC BY-SA 4.0 at github.com/heyobi/corewords.':
        'Tanımlar, örnek cümleler, Türkçe karşılıklar, dersler ve phrasal verb seçkisi Corewords için yazıldı. Kelime listeleriyle birlikte github.com/heyobi/corewords adresinde CC BY-SA 4.0 lisansıyla paylaşılıyor.',
    'The Corewords source code is open source under the MIT License.': 'Corewords\'ün kaynak kodu MIT Lisansı ile açık kaynaktır.',
    # Paywall
    'One purchase, yours forever. No subscription, no ads, no account.': 'Tek seferlik satın alma, sonsuza dek sizin. Abonelik yok, reklam yok, hesap yok.',
    'Extended list: 2,200 more words': 'Genişletilmiş liste: 2.200 kelime daha',
    'Go from 92% to about 98% of everyday English, with meanings and examples.': 'Anlamları ve örnekleriyle günlük İngilizcenin %92\'sinden yaklaşık %98\'ine çıkın.',
    '205 phrasal verbs': '205 phrasal verb',
    'get over, put up with, figure out… drilled with spaced repetition.': 'get over, put up with, figure out… aralıklı tekrarla pekiştirilir.',
    'Pronunciation trainer': 'Telaffuz çalıştırıcı',
    'All 70 minimal pairs for the sounds Turkish speakers find hardest.': 'Türkçe konuşanların en çok zorlandığı sesler için 70 minimal çiftin tamamı.',
    'Say it': 'Söyle',
    'Pronounce words out loud and get checked on your device.': 'Kelimeleri sesli söyleyin, telaffuzunuz cihazınızda kontrol edilsin.',
    'Free forever: the 2,800 core words, all grammar lessons, the 44-sound chart, the placement test, reminders and progress.':
        'Her zaman ücretsiz: 2.800 temel kelime, tüm dil bilgisi dersleri, 44 sesli tablo, seviye testi, hatırlatıcılar ve ilerleme.',
    'Unlock for %@': '%@ karşılığında aç', 'Not now': 'Şimdi değil',
    "The App Store isn't available right now. Please try again later.": 'App Store\'a şu anda ulaşılamıyor. Lütfen daha sonra yeniden deneyin.',
    'The purchase is waiting for approval.': 'Satın alma onay bekliyor.',
    "The purchase didn't go through. Nothing was charged.": 'Satın alma tamamlanmadı. Ücret alınmadı.',
    'No earlier purchase was found for this Apple Account.': 'Bu Apple Hesabı için daha önce yapılmış bir satın alma bulunamadı.',
    # Onboarding
    "Learn the English words you'll actually meet, most useful first.": 'Gerçekten karşılaşacağınız İngilizce kelimeleri, en faydalısından başlayarak öğrenin.',
    '2,800 core words cover about 92% of everyday English text.': '2.800 temel kelime, günlük İngilizce metinlerin yaklaşık %92\'sini karşılar.',
    "Spaced repetition brings each word back just before you'd forget it.": 'Aralıklı tekrar, her kelimeyi tam unutmak üzereyken karşınıza getirir.',
    'US and UK pronunciation with IPA for every word.': 'Her kelime için IPA ile ABD ve İngiltere telaffuzu.',
    'Works offline. No account, no ads, no tracking.': 'İnternetsiz çalışır. Hesap yok, reklam yok, izleme yok.',
    'Get started': 'Başlayalım',
    'How should we teach you?': 'Size nasıl öğretelim?', 'Meanings': 'Anlamlar',
    'American': 'Amerikan', 'British': 'İngiliz',
    'Turkish translation and English definition': 'Türkçe karşılık ve İngilizce tanım', 'Simple English definitions': 'Basit İngilizce tanımlar',
    'You can always hear both. Tap to listen.': 'İkisini de her zaman dinleyebilirsiniz. Dinlemek için dokunun.',
    'Your daily pace': 'Günlük temponuz',
    'New words each day. Reviews are added automatically.': 'Her gün yeni kelimeler. Tekrarlar otomatik eklenir.',
    '5 words · Relaxed': '5 kelime · Rahat', '10 words · Steady': '10 kelime · Düzenli', '20 words · Intensive': '20 kelime · Yoğun',
    'About 5 minutes a day': 'Günde yaklaşık 5 dakika', 'About 10 minutes a day': 'Günde yaklaşık 10 dakika', 'About 20 minutes a day': 'Günde yaklaşık 20 dakika',
    'Remind me every evening': 'Her akşam hatırlat',
    'A local notification at 19:00. Change it any time.': 'Saat 19:00\'da yerel bildirim. İstediğiniz zaman değiştirin.',
    'Where should you start?': 'Nereden başlamalısınız?',
    "A quick test (about 40 questions, 3 minutes) finds the words you already know so you don't waste time on them.":
        'Kısa bir test (yaklaşık 40 soru, 3 dakika) bildiğiniz kelimeleri bulur, böylece onlara zaman harcamazsınız.',
    'Take the placement test': 'Seviye testini çöz',
    "I'm a beginner, start from the first word": 'Yeni başlıyorum, ilk kelimeden başla',
    # Placement
    'Do you know this word?': 'Bu kelimeyi biliyor musunuz?',
    "I don't know this word": 'Bu kelimeyi bilmiyorum',
    "Let's start from the beginning": 'Baştan başlayalım',
    "You'll learn the most frequent words first. They make the biggest difference.": 'Önce en sık kullanılan kelimeleri öğreneceksiniz. En büyük farkı onlar yaratır.',
    'You already know about %lld words': 'Zaten yaklaşık %lld kelime biliyorsunuz',
    "That's roughly %lld%% of everyday English. We'll mark them as known and start you at word %lld.":
        'Bu, günlük İngilizcenin kabaca %%%1$lld kadarı. Bunları biliniyor olarak işaretleyip %2$lld. kelimeden başlatacağız.',
    'Unsure about a word later? Find it in Words and reset it.': 'Sonra bir kelimeden emin olamazsanız Kelimeler\'de bulup sıfırlayın.',
    'Start learning': 'Öğrenmeye başla',
    # Reminders
    'Time for your English words': 'İngilizce kelime zamanı',
    '%lld words are ready for review. A few minutes keeps them in your memory.': '%lld kelime tekrar için hazır. Birkaç dakika onları hafızanızda tutar.',
    'Learn a few new words today. The most useful ones come first.': 'Bugün birkaç yeni kelime öğrenin. En faydalıları önce gelir.',
    'Keep your %lld-day streak going!': '%lld günlük serinizi sürdürün!',
    # Info.plist
    'Corewords listens on your device to check how you pronounce a word. Nothing is recorded or sent anywhere.':
        'Corewords, bir kelimeyi nasıl telaffuz ettiğinizi kontrol etmek için cihazınızda dinler. Hiçbir şey kaydedilmez ya da bir yere gönderilmez.',
    'The microphone is used only while you hold the Say It button, to check your pronunciation on this device.':
        'Mikrofon yalnızca Söyle düğmesine basılı tuttuğunuz sürece, telaffuzunuzu bu cihazda kontrol etmek için kullanılır.',
    # Feedback round 1 (learning flow, Say it, accents, grammar)
    'I know it': 'Biliyorum', 'Learn it': 'Öğren',
    'Quick check: what does it mean?': 'Hızlı kontrol: anlamı ne?',
    'It will come back in a few minutes.': 'Birkaç dakika içinde tekrar gelecek.',
    'Learned! Next review tomorrow.': 'Öğrenildi! Sonraki tekrar yarın.',
    'Learned! Next review in %lld days.': 'Öğrenildi! Sonraki tekrar %lld gün sonra.',
    'Mastered! In your long-term memory now. Next check in %lld days.': 'Ustalaştınız! Artık uzun süreli hafızanızda. Sonraki kontrol %lld gün sonra.',
    'Stronger memory: next review in %lld days.': 'Hafıza güçlendi: sonraki tekrar %lld gün sonra.',
    "You know it. Skipped; we'll check it once more in 3 weeks.": 'Biliyorsunuz. Atlandı; 3 hafta sonra bir kez daha kontrol edeceğiz.',
    "No problem, let's learn it properly.": 'Sorun değil, düzgünce öğrenelim.',
    'Too easy': 'Çok kolay', 'Shows this word again much later': 'Bu kelimeyi çok daha sonra tekrar gösterir',
    'words learned': 'öğrenilen kelime', 'New in your memory': 'Hafızanızdaki yeni kelimeler',
    '+%@ points of everyday English in this session.': 'Bu derste günlük İngilizcede +%@ puan.',
    '%lld words you already knew were skipped after a quick check.': 'Zaten bildiğiniz %lld kelime hızlı bir kontrolden sonra atlandı.',
    'words you know': 'bildiğiniz kelime', '+%lld today': 'bugün +%lld',
    '%lld mastered': '%lld ustalaşıldı', '%lld learning': '%lld öğreniliyor', 'Mastered': 'Ustalaşıldı',
    'Hold to say it': 'Söylemek için basılı tutun', 'Nothing heard': 'Bir şey duyulmadı',
    'Allow the microphone and speech recognition in Settings to use Say it.': "Söyle özelliği için Ayarlar'dan mikrofon ve konuşma tanımaya izin verin.",
    "On-device English speech recognition isn't available on this device yet. In iOS Settings › General › Keyboard, turn on Dictation and add English.":
        "Cihaz üzerinde İngilizce konuşma tanıma bu cihazda henüz yok. iOS Ayarlar › Genel › Klavye bölümünde Dikte'yi açıp İngilizce ekleyin.",
    'Show both accents': 'İki aksanı da göster',
    'Mode': 'Mod', 'Listen': 'Dinle', 'Speak': 'Konuş', 'not %@': '%@ değil',
    'Tenses and grammar': 'Zamanlar ve dil bilgisi',
    'The structures that hold the words together: present, past and future, the present perfect, comparatives, conditionals and more. Short, with examples and a quiz.':
        'Kelimeleri bir arada tutan yapılar: şimdiki, geçmiş ve gelecek zaman, present perfect, karşılaştırmalar, koşul cümleleri ve daha fazlası. Kısa, örnekli ve testli.',
}

# Literals that are not UI text (symbols, keys, file names, formats, sample sentences spoken aloud).
IGNORE = re.compile(r'^(|[ ]|com\.heyobi.*|[a-z]:|[a-z0-9.]+(\.[a-z0-9.]+)*|.*\\\(.*|%.*|[%@×·—•:°–/].*|-shots.*|\d-.*|Logo|AccentColor|'
                    r'CFBundleShortVersionString|https?://.*|ready|next|done|shots|pro|progress\.json|[A-Z]{2,3}|US · UK|Aa|PRO|_____|'
                    r'en-US|en-GB|en_US|en|tr|det|prep|conj|pron|modal|num|phr|basic|core|ext|s|i|journey|borrow|thought|water|'
                    r'The most useful words come first\.|Missing or invalid .*|.*\{.*|\[|\]|word|w:.*|p:.*|tortoise.*|hare|xmark|.*\.fill|'
                    r'[a-z]+(\.[a-z]+)+|yyyy-MM-dd|🇹🇷|.*\\.*)$')

found = set()
for f in glob.glob('Corewords/**/*.swift', recursive=True):
    if '/Logic/' in f.replace('\\', '/'):
        continue
    for line in open(f, encoding='utf-8'):
        if line.strip().startswith('//'):
            continue
        for m in re.finditer(r'"((?:[^"\\]|\\.)*)"', line):
            found.add(m.group(1))
missing = sorted(s for s in found if s not in TR and not IGNORE.match(s))
print('untranslated literals:', missing)
interp = sorted(s for s in found if '\\(' in s)
print('interpolated (check keys exist):', interp)

strings = {}
for k, v in TR.items():
    strings[k] = {'localizations': {'tr': {'stringUnit': {'state': 'translated', 'value': v}}}}
cat = {'sourceLanguage': 'en', 'strings': dict(sorted(strings.items())), 'version': '1.0'}
json.dump(cat, open('Corewords/Localizable.xcstrings', 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
print(len(strings), 'strings written')

# Info.plist strings for Turkish.
plist = {
    'NSSpeechRecognitionUsageDescription': TR['Corewords listens on your device to check how you pronounce a word. Nothing is recorded or sent anywhere.'],
    'NSMicrophoneUsageDescription': TR['The microphone is used only while you hold the Say It button, to check your pronunciation on this device.'],
}
icat = {'sourceLanguage': 'en', 'version': '1.0', 'strings': {
    k: {'localizations': {'tr': {'stringUnit': {'state': 'translated', 'value': v}}}} for k, v in plist.items()}}
json.dump(icat, open('Corewords/InfoPlist.xcstrings', 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
