/// Word lists used by the mock catalog and the generated guide.
///
/// Channel names are realistic (many are real broadcaster names, which is
/// normal for IPTV test data). Movie, series, cast and programme names are
/// invented. Nothing here is copied from a real provider's catalog.
library;

// ---------------------------------------------------------------------------
// Places
// ---------------------------------------------------------------------------

const trCities = <String>[
  'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Amasya', 'Ankara', //
  'Antalya', 'Artvin', 'Aydın', 'Balıkesir', 'Bilecik', 'Bingöl',
  'Bitlis', 'Bolu', 'Burdur', 'Bursa', 'Çanakkale', 'Çankırı', 'Çorum',
  'Denizli', 'Diyarbakır', 'Edirne', 'Elazığ', 'Erzincan', 'Erzurum',
  'Eskişehir', 'Gaziantep', 'Giresun', 'Gümüşhane', 'Hakkâri', 'Hatay',
  'Isparta', 'Mersin', 'İstanbul', 'İzmir', 'Kars', 'Kastamonu', 'Kayseri',
  'Kırklareli', 'Kırşehir', 'Kocaeli', 'Konya', 'Kütahya', 'Malatya',
  'Manisa', 'Kahramanmaraş', 'Mardin', 'Muğla', 'Muş', 'Nevşehir', 'Niğde',
  'Ordu', 'Rize', 'Sakarya', 'Samsun', 'Siirt', 'Sinop', 'Sivas',
  'Tekirdağ', 'Tokat', 'Trabzon', 'Tunceli', 'Şanlıurfa', 'Uşak', 'Van',
  'Yozgat', 'Zonguldak', 'Aksaray', 'Bayburt', 'Karaman', 'Kırıkkale',
  'Batman', 'Şırnak', 'Bartın', 'Ardahan', 'Iğdır', 'Yalova', 'Karabük',
  'Kilis', 'Osmaniye', 'Düzce',
];

const ukTowns = <String>[
  'London', 'Manchester', 'Birmingham', 'Leeds', 'Liverpool', 'Bristol', //
  'Sheffield', 'Newcastle', 'Nottingham', 'Leicester', 'Glasgow',
  'Edinburgh', 'Cardiff', 'Belfast', 'Brighton', 'Oxford', 'Cambridge',
  'York', 'Bath', 'Plymouth', 'Southampton', 'Portsmouth', 'Norwich',
  'Exeter', 'Coventry', 'Derby', 'Hull', 'Swansea', 'Aberdeen', 'Dundee',
  'Inverness', 'Chester', 'Durham', 'Canterbury', 'Lincoln', 'Reading',
  'Luton', 'Bournemouth', 'Ipswich', 'Preston',
];

const deCities = <String>[
  'Berlin', 'Hamburg', 'München', 'Köln', 'Frankfurt', 'Stuttgart', //
  'Düsseldorf', 'Leipzig', 'Dortmund', 'Essen', 'Bremen', 'Dresden',
  'Hannover', 'Nürnberg', 'Duisburg', 'Bochum', 'Wuppertal', 'Bielefeld',
  'Bonn', 'Münster', 'Mannheim', 'Karlsruhe', 'Augsburg', 'Wiesbaden',
  'Mönchengladbach', 'Gelsenkirchen', 'Aachen', 'Braunschweig', 'Kiel',
  'Chemnitz', 'Halle', 'Magdeburg', 'Freiburg', 'Krefeld', 'Lübeck',
  'Mainz', 'Erfurt', 'Rostock', 'Kassel', 'Saarbrücken', 'Würzburg',
  'Göttingen', 'Osnabrück', 'Tübingen', 'Fürth', 'Regensburg', 'Jena',
  'Görlitz',
];

const itCities = <String>[
  'Roma', 'Milano', 'Napoli', 'Torino', 'Palermo', 'Genova', 'Bologna', //
  'Firenze', 'Bari', 'Catania', 'Venezia', 'Verona', 'Messina', 'Padova',
  'Trieste', 'Brescia', 'Taranto', 'Prato', 'Parma', 'Modena', 'Perugia',
  'Livorno', 'Ravenna', 'Cagliari', 'Foggia', 'Rimini', 'Salerno',
  'Ferrara', 'Sassari', 'Latina', 'Monza', 'Bergamo', 'Forlì', 'Trento',
  'Vicenza', 'Terni', 'Bolzano', 'Novara', 'Piacenza', 'Ancona', 'Lecce',
  'Cantù', 'Pesaro',
];

/// Cities for the extra countries that only appear in the large catalog.
const otherCities = <String, List<String>>{
  'FR': [
    'Paris', 'Marseille', 'Lyon', 'Toulouse', 'Nice', 'Nantes', //
    'Strasbourg', 'Montpellier', 'Bordeaux', 'Lille', 'Rennes', 'Reims',
    'Saint-Étienne', 'Toulon', 'Grenoble', 'Dijon', 'Angers', 'Nîmes',
    'Besançon', 'Orléans',
  ],
  'NL': [
    'Amsterdam', 'Rotterdam', 'Den Haag', 'Utrecht', 'Eindhoven', //
    'Groningen', 'Tilburg', 'Almere', 'Breda', 'Nijmegen', 'Zwolle',
  ],
  'PL': [
    'Warszawa', 'Kraków', 'Łódź', 'Wrocław', 'Poznań', 'Gdańsk', //
    'Szczecin', 'Bydgoszcz', 'Lublin', 'Białystok', 'Katowice', 'Gdynia',
    'Częstochowa', 'Toruń', 'Kielce',
  ],
  'ES': [
    'Madrid', 'Barcelona', 'Valencia', 'Sevilla', 'Zaragoza', 'Málaga', //
    'Murcia', 'Palma', 'Bilbao', 'Alicante', 'Córdoba', 'Valladolid',
    'Vigo', 'Gijón', 'A Coruña', 'Granada', 'Cádiz', 'León',
  ],
  'PT': [
    'Lisboa', 'Porto', 'Braga', 'Coimbra', 'Funchal', 'Setúbal', 'Évora', //
    'Aveiro', 'Faro', 'Viseu',
  ],
  'GR': [
    'Αθήνα', 'Θεσσαλονίκη', 'Πάτρα', 'Ηράκλειο', 'Λάρισα', 'Βόλος', //
    'Ιωάννινα', 'Χανιά',
  ],
  'RU': [
    'Москва', 'Санкт-Петербург', 'Казань', 'Новосибирск', 'Екатеринбург', //
    'Самара', 'Сочи', 'Омск',
  ],
  'AR': ['دبي', 'القاهرة', 'الرياض', 'بيروت', 'عمّان', 'الدوحة'],
  'AZ': [
    'Bakı', 'Gəncə', 'Sumqayıt', 'Mingəçevir', 'Şəki', 'Lənkəran', //
    'Şirvan', 'Naxçıvan',
  ],
  'ALB': ['Tiranë', 'Durrës', 'Vlorë', 'Shkodër', 'Elbasan', 'Korçë'],
  'EXYU': [
    'Beograd', 'Zagreb', 'Sarajevo', 'Ljubljana', 'Skopje', 'Novi Sad', //
    'Split', 'Niš', 'Podgorica', 'Banja Luka', 'Tuzla', 'Rijeka',
  ],
  'US': [
    'New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix', //
    'Philadelphia', 'San Antonio', 'San Diego', 'Dallas', 'Austin', 'Miami',
    'Seattle', 'Denver', 'Boston', 'Atlanta', 'Detroit',
  ],
  'IN': [
    'Mumbai', 'Delhi', 'Bengaluru', 'Chennai', 'Kolkata', 'Hyderabad', //
    'Pune', 'Jaipur',
  ],
  'KU': ['Hewlêr', 'Silêmanî', 'Duhok', 'Kerkûk'],
};

// ---------------------------------------------------------------------------
// Channels
// ---------------------------------------------------------------------------

/// Base channel names per country code and genre key.
///
/// Genre keys: general, news, sports, docs, kids, movies, music, local,
/// radio, allday (24/7 loop channels), ppv.
const channelNames = <String, Map<String, List<String>>>{
  'TR': {
    'general': [
      'ATV', 'Star TV', 'NOW', 'TV8', 'Kanal 7', 'Beyaz TV', 'TV 8,5', //
      'Teve2', 'A2', '360', 'TRT 2', 'TRT Avaz', 'TRT Kurdî', 'TRT Türk',
      'Kanal D Drama', 'Show Max', 'Star Max', 'ATV Avrupa', 'Euro D',
      'Euro Star', 'Show Türk', 'Kanal Avrupa', 'TV 4', 'Ekol TV', 'Dost TV',
      'Kanal T', 'Life TV', 'Meltem TV', 'Ulusal Kanal', 'Flash TV',
    ],
    'news': [
      'TRT Haber', 'Habertürk', 'CNN Türk', 'NTV', 'Haber Global', //
      'TGRT Haber', 'Halk TV', 'Sözcü TV', 'Tele1', 'A Haber', '24 TV',
      'Ülke TV', 'TV100', 'Bloomberg HT', 'TRT World', 'Ekotürk', 'Flash Haber',
      'Haber 7 TV', 'Ekol Haber', 'Kanal Haber',
    ],
    'sports': [
      'TRT Spor', 'TRT Spor Yıldız', 'A Spor', 'beIN Sports 1', //
      'beIN Sports 2', 'beIN Sports 3', 'beIN Sports 4', 'beIN Sports 5',
      'beIN Sports Max 1', 'beIN Sports Max 2', 'beIN Sports Haber', 'S Sport',
      'S Sport 2', 'Tivibu Spor 1', 'Tivibu Spor 2', 'Tivibu Spor 3',
      'Tivibu Spor 4', 'Smart Spor', 'Smart Spor 2', 'Exxen Spor 1',
      'Exxen Spor 2', 'Exxen Spor 3', 'Exxen Spor 4', 'Sports TV', 'FB TV',
      'GS TV', 'BJK TV', 'TS TV', 'TJK TV', 'Eurosport 1', 'Eurosport 2',
      'NBA TV', 'Fight Box', 'Golf Kanalı', 'At Yarışı TV', 'Spor Smart',
    ],
    'docs': [
      'TRT Belgesel', 'National Geographic', 'Nat Geo Wild', //
      'Discovery Channel', 'DMAX', 'TLC', 'History', 'Animal Planet',
      'Viasat Explore', 'Viasat History', 'Viasat Nature', 'Da Vinci',
      'Love Nature', 'Yaban TV', 'Av TV', 'Çiftçi TV', 'Tarım TV', 'Gezi TV',
      'Bilim TV', 'Doğa TV',
    ],
    'kids': [
      'TRT Çocuk', 'Minika Çocuk', 'Minika Go', 'Cartoon Network', //
      'Disney Junior', 'Nickelodeon', 'Nick Jr', 'Baby TV', 'Duck TV',
      'Planet Çocuk', 'Cartoonito', 'Boomerang', 'Çizgi Dünyası', 'Masal TV',
      'Okul Öncesi TV',
    ],
    'movies': [
      'Movie Smart Premium', 'Movie Smart Gold', 'Movie Smart Action', //
      'Movie Smart Fest', 'Movie Smart Türk', 'Sinema TV', 'Sinema 2',
      'Sinema Aksiyon', 'Sinema Komedi', 'Sinema Aile', 'Sinema Yerli',
      'Sinema 1001', 'FX', 'Fox Crime', 'Dizi Smart Max', 'Dizi Smart Premium',
      'Yeşilçam TV', 'Tivibu Sinema 1', 'Tivibu Sinema 2', 'Filmbox',
      'Filmbox Premium', 'Epic Drama', 'Paramount Network',
    ],
    'music': [
      'Kral Pop', 'Power Türk', 'Number 1 Türk', 'Dream Türk', 'Kral TV', //
      'Power TV', 'Number 1', 'TRT Müzik', 'Milyon TV', 'Türkü TV',
      'Arabesk TV', 'Slow Türk', 'Joy Türk',
    ],
    'local': [
      'Kanal 34', 'Ege TV', 'Kanal 33', 'Kanal B', 'Çukurova TV', 'Kanal 3', //
      'Kanal 26', 'Kanal 15', 'TV 52', 'Kanal Urfa', 'Gün TV', 'Aksu TV',
      'Vizyon 58', 'Ankara TV', 'Bursa AS TV', 'Kocaeli TV', 'Antalya Kent TV',
      'Diyarbakır Gün TV', 'Erzurum Kanal 25', 'Gaziantep Olay TV',
    ],
    'radio': [
      'TRT FM', 'TRT Radyo 1', 'TRT Nağme', 'Kral FM', 'Power FM', //
      'Süper FM', 'Joy FM', 'Radyo Fenomen', 'Virgin Radio', 'Metro FM',
      'Best FM', 'Radyo D', 'Number 1 FM', 'Alem FM', 'Show Radyo',
      'Radyo Viva', 'Radyo Türkü',
    ],
    'allday': [
      '7/24 Bizim Mahalle', '7/24 Kayıp Şehir', '7/24 Sıcak Kafa', //
      '7/24 Çizgi Film', '7/24 Komedi Klasikleri', '7/24 Polisiye',
      '7/24 Belgesel', '7/24 Yeşilçam Aşk', '7/24 Stand-Up', '7/24 Masal Saati',
      '7/24 Kervan Yolu', '7/24 Gece Yarısı Dosyaları',
    ],
  },
  'UK': {
    'general': [
      'BBC One', 'BBC Two', 'BBC Three', 'BBC Four', 'ITV1', 'ITV2', 'ITV3', //
      'ITV4', 'Channel 4', 'Channel 5', 'E4', 'More4', 'Dave', 'Gold',
      'Alibi', 'W', 'Yesterday', 'Drama', 'Sky Atlantic', 'Sky Showcase',
      'Sky Max', 'Sky Witness', 'Sky Comedy', 'Comedy Central UK', 'Quest',
      'Really', 'Pick', 'Challenge', '5Star', 'Blaze',
    ],
    'news': [
      'BBC News', 'Sky News', 'GB News', 'Al Jazeera English', //
      'Bloomberg UK', 'CNBC Europe', 'Euronews UK', 'BBC Parliament',
    ],
    'sports': [
      'Sky Sports Main Event', 'Sky Sports Premier League', //
      'Sky Sports Football', 'Sky Sports Cricket', 'Sky Sports Golf',
      'Sky Sports F1', 'Sky Sports Action', 'Sky Sports Arena',
      'Sky Sports News', 'TNT Sports 1', 'TNT Sports 2', 'TNT Sports 3',
      'TNT Sports 4', 'Premier Sports 1', 'Premier Sports 2', 'LaLiga TV',
      'Racing TV', 'Eurosport UK',
    ],
    'docs': [
      'Discovery UK', 'Nat Geo UK', 'History UK', 'Sky Nature', //
      'Sky Documentaries', 'Sky History', 'Crime & Investigation',
    ],
    'kids': [
      'CBBC', 'CBeebies', 'Nick Jr UK', 'Cartoon Network UK', 'Pop', //
      'Tiny Pop', 'CITV',
    ],
    'movies': [
      'Film4', 'Sky Cinema Premiere', 'Sky Cinema Action', //
      'Sky Cinema Comedy', 'Sky Cinema Family', 'Sky Cinema Thriller',
      'Sky Cinema Drama', 'Sky Cinema Sci-Fi & Horror', 'Sky Cinema Greats',
      'Talking Pictures TV', 'Great! Movies',
    ],
    'music': ['MTV UK', 'Kerrang!', 'Kiss TV', 'Magic TV', 'Now 80s'],
    'local': [
      'BBC One London', 'BBC One Scotland', 'BBC One Wales', //
      'BBC One Northern Ireland', 'BBC One North West', 'BBC One Yorkshire',
      'ITV1 Granada', 'ITV1 Tyne Tees', 'STV', 'UTV',
    ],
    'ppv': ['Box Office Event'],
  },
  'DE': {
    'general': [
      'Das Erste', 'ZDF', 'RTL', 'SAT.1', 'ProSieben', 'VOX', 'kabel eins', //
      'RTLZWEI', 'ZDFneo', '3sat', 'arte', 'Phoenix', 'BR Fernsehen', 'WDR',
      'NDR', 'MDR', 'SWR', 'hr-fernsehen', 'rbb', 'ProSieben MAXX', 'sixx',
      'Tele 5', 'Sky One DE', 'ServusTV', 'ORF 1', 'ORF 2', 'SRF 1',
    ],
    'news': ['n-tv', 'WELT', 'tagesschau24', 'Euronews DE', 'Bloomberg DE'],
    'sports': [
      'Sport1', 'Eurosport 1 DE', 'Sky Sport Bundesliga 1', //
      'Sky Sport Bundesliga 2', 'Sky Sport Top Event', 'Sky Sport News',
      'DAZN 1 DE', 'DAZN 2 DE', 'Sky Sport Austria',
    ],
    'docs': [
      'DMAX DE', 'Kabel Eins Doku', 'N24 Doku', 'Spiegel TV Wissen', //
      'ZDFinfo', 'Terra Mater TV',
    ],
    'kids': [
      'KiKA', 'SUPER RTL', 'Nickelodeon DE', 'Disney Channel DE', //
      'Toggo Plus',
    ],
    'movies': [
      'Sky Cinema Premieren', 'Sky Cinema Action DE', //
      'Sky Cinema Family DE', 'Sky Cinema Highlights', 'Sky Krimi',
      'Kinowelt TV', 'Heimatkanal',
    ],
    'music': ['Deluxe Music', 'MTV Germany', 'Volksmusik TV'],
    'local': [
      'Münchner Lokal TV', 'Hamburg 1', 'TV Berlin', 'Rhein-Neckar TV', //
      'center.tv Köln', 'Leipzig Fernsehen', 'Sachsen Fernsehen',
    ],
  },
  'IT': {
    'general': [
      'Rai 1', 'Rai 2', 'Rai 3', 'Rete 4', 'Canale 5', 'Italia 1', 'La7', //
      'TV8 Italia', 'Nove', 'Rai 4', 'Rai 5', 'Rai Premium', 'Rai Storia',
      'Real Time', 'Cielo', '20 Mediaset', 'Mediaset Extra', 'La5', 'Giallo',
      'Sky Uno',
    ],
    'news': ['Rai News 24', 'Sky TG24', 'TGCom24', 'Euronews IT'],
    'sports': [
      'Rai Sport', 'Sky Sport Uno', 'Sky Sport Calcio', 'Sky Sport Arena', //
      'Sky Sport F1', 'Sky Sport MotoGP', 'DAZN 1 IT', 'Eurosport 1 IT',
      'Sportitalia',
    ],
    'docs': ['Focus', 'DMAX IT', 'Rai Scuola', 'Nat Geo Italia'],
    'kids': ['Rai Yoyo', 'Rai Gulp', 'Boing', 'Cartoonito IT', 'Frisbee', 'K2'],
    'movies': [
      'Rai Movie', 'Iris', 'Cine34', 'Top Crime', 'Sky Cinema Uno', //
      'Sky Cinema Due', 'Sky Cinema Comedy IT',
    ],
    'music': ['Radio Italia TV', 'RDS Social TV', 'Kiss Kiss TV'],
    'local': [
      'Telelombardia', 'Antenna Sud', 'TeleNorba', 'Canale Italia', //
      'Telenuovo', 'Rete Veneta',
    ],
  },
  'AZ': {
    'general': [
      'AzTV', 'İctimai TV', 'ARB', 'ARB Günəş', 'Xəzər TV', 'Space TV', //
      'Lider TV', 'Region TV', 'Mədəniyyət TV', 'İdman TV', 'CBC Sport',
      'Real TV AZ',
    ],
  },
  'FR': {
    'general': [
      'TF1', 'France 2', 'France 3', 'Canal+', 'France 5', 'M6', 'C8', 'W9', //
      'TMC', 'TFX', 'NRJ 12', 'France 4', 'Téva', 'Paris Première',
      'Chérie 25', 'RMC Découverte', 'Ushuaïa TV',
    ],
    'news': ['BFM TV', 'CNews', 'LCI', 'franceinfo', 'LCP'],
    'sports': ['RMC Sport 1', 'beIN Sports FR 1', 'Eurosport FR', 'L’Équipe'],
  },
  'NL': {
    'general': [
      'NPO 1', 'NPO 2', 'NPO 3', 'RTL 4', 'RTL 5', 'SBS6', 'RTL 7', //
      'Veronica', 'Net5', 'RTL 8', 'SBS9',
    ],
    'sports': ['Ziggo Sport', 'ESPN NL'],
  },
  'PL': {
    'general': [
      'TVP1', 'TVP2', 'Polsat', 'TVN', 'TV4 PL', 'TVN Turbo', 'Puls', //
      'Polonia 1', 'Kino Polska', 'Stopklatka', 'Zoom TV', 'Nowa TV',
      'TVP Kultura', 'TVP Historia',
    ],
    'news': ['TVN24', 'Polsat News', 'TVP Info', 'Wydarzenia 24'],
    'sports': [
      'Canal+ Sport PL',
      'Eleven Sports 1 PL',
      'Polsat Sport',
      'TVP Sport',
    ],
  },
  'ES': {
    'general': [
      'La 1', 'La 2', 'Antena 3', 'Cuatro', 'Telecinco', 'laSexta', 'Neox', //
      'Nova', 'Mega', 'FDF', 'Energy', 'Divinity', 'Telemadrid', 'TV3',
      'Canal Sur', 'À Punt',
    ],
    'sports': ['Teledeporte', 'DAZN LaLiga', 'Movistar Deportes', 'M+ Vamos'],
    'kids': ['Clan', 'Boing ES'],
  },
  'PT': {
    'general': [
      'RTP1', 'RTP2', 'SIC', 'TVI', 'CMTV', 'SIC Mulher', 'TVI Ficção', //
      'Porto Canal',
    ],
    'news': ['SIC Notícias', 'CNN Portugal', 'RTP3'],
    'sports': ['Sport TV 1', 'Sport TV 2', 'Benfica TV', 'Canal 11'],
  },
  'GR': {
    'general': [
      'ΕΡΤ1', 'ΕΡΤ2', 'ΕΡΤ3', 'ANT1', 'Alpha', 'Star Channel GR', //
      'Open Beyond', 'Skai', 'Mega GR',
    ],
    'sports': ['Cosmote Sport 1', 'Nova Sports 1'],
  },
  'RU': {
    'general': [
      'Первый канал', 'Россия 1', 'НТВ', 'Пятница!', 'ТНТ', 'СТС', //
      'Рен ТВ', 'Звезда', 'Карусель', 'Мир', 'ТВ-3',
    ],
    'sports': ['Матч ТВ'],
  },
  'AR': {
    'general': [
      'قناة الأخبار', 'الرياضية 1', 'دراما ألوان', 'سينما 1', 'كرتون 1', //
      'الوثائقية', 'MBC 1', 'MBC Drama', 'Rotana Cinema',
    ],
  },
  'ALB': {
    'general': [
      'Top Channel', 'Klan', 'RTSH 1', 'RTSH 2', 'Vizion Plus', //
      'TV Klan Kosova', 'RTK 1', 'Report TV', 'News 24 AL',
    ],
    'sports': ['Tring Sport 1', 'SuperSport 1 AL'],
  },
  'EXYU': {
    'general': [
      'RTS 1', 'RTS 2', 'Pink', 'Prva', 'N1 Srbija', 'HRT 1', 'HRT 2', //
      'RTL Hrvatska', 'Nova TV', 'BHT 1', 'FTV', 'Hayat', 'OBN',
      'RTV Slovenija 1', 'POP TV', 'MTV Makedonija', 'Sitel', 'TV Vijesti',
      'RTV Pančevo', 'TV Šabac',
    ],
    'sports': [
      'Arena Sport 1',
      'Arena Sport 2',
      'Sport Klub 1',
      'Sport Klub 2',
    ],
  },
  'US': {
    'general': [
      'ABC', 'NBC', 'CBS', 'FOX', 'CW', 'PBS', 'AMC', 'HBO', 'HBO 2', //
      'Showtime', 'Starz', 'Cinemax', 'TNT', 'TBS', 'USA Network', 'FX USA',
      'A&E', 'Food Network', 'HGTV', 'Bravo', 'E!',
    ],
    'news': ['CNN', 'Fox News', 'MSNBC', 'CNBC', 'Bloomberg TV'],
    'sports': ['ESPN', 'ESPN 2', 'Fox Sports 1', 'NFL Network', 'MLB Network'],
  },
  'IN': {
    'general': [
      'Star Plus', 'Zee TV', 'Sony TV', 'Colors TV', 'Star Bharat', //
      'Sony SAB', 'Zee Cinema', 'Star Gold', 'Sony Max', 'Sun TV', 'Asianet',
    ],
    'news': ['Aaj Tak', 'NDTV 24x7'],
    'sports': ['Star Sports 1', 'Sony Ten 1'],
  },
  'KU': {
    'general': [
      'Rudaw', 'Kurdistan 24', 'Kurdsat', 'Ronahî TV', 'Stêrk TV', //
      'Zarok TV', 'Kurdmax',
    ],
  },
};

/// Suffixes used to make synthetic local channels from city names
/// (`İzmir Haber`, `Lübeck TV`, …) for the large catalog.
const localSuffixes = <String, List<String>>{
  'TR': [
    'TV', 'Haber', 'Kanal', 'Türk', 'Gündem', 'Medya', 'Life', 'Ekspres', //
    'Spor TV', 'Kent TV', 'Olay TV', 'Yerel', 'Ses TV', 'Vizyon',
  ],
  'UK': ['TV', 'Local', 'Live', 'Community TV', 'News'],
  'DE': ['TV', 'Regional', 'Lokal TV', 'Fernsehen', 'Eins'],
  'IT': ['TV', 'Tele', 'Canale', 'Notizie', 'Sport'],
  'other': ['TV', 'Local', 'News', 'Sport', '1', '2'],
};

// ---------------------------------------------------------------------------
// Movies and series
// ---------------------------------------------------------------------------

const trMovieTitles = <String>[
  'Sessiz Gece', 'Kayıp Şehir', 'Son Yaz', 'Gölgeler', 'Kırık Kanatlar', //
  'Uzak Sesler', 'Yalnız Kurt', 'Derin Sular', 'Soğuk Rüzgâr',
  'Beyaz Kelebek', 'Kara Deniz', 'Mavi Liman', 'Kızıl Elma', 'Altın Kafes',
  'Gümüş Ay', 'Çılgın Kasım', 'Güzel Günler', 'Büyük Oyun', 'Küçük Sırlar',
  'Masum Yalanlar', 'Yasak Bahçe', 'Ölümsüz Aşk', 'Unutulmuş Yıllar',
  'İstanbul Rüyası', 'Ankara Ekspresi', "İzmir'de Bir Gece", 'Gece Treni',
  'Rüzgârın Sesi', 'Yağmur Sonrası', 'Kar Tanesi', 'Ateş Çemberi',
  'Fırtına Öncesi', 'Ayna', 'Saat Kulesi', 'Kapı Aralığı',
  'Pencereden Bakan Kız', 'Mektup', 'Eski Dostlar', 'Kervan', 'Hayalet Konak',
  'Köprüdeki Adam', 'Son Tren', 'Gizli Dosya', 'Şafak Operasyonu',
  'Kırmızı Bisiklet', 'Bir Yaz Masalı', 'Ağustos Böceği', 'Dönüş Yolu',
  'Sonbahar Mektupları', 'Tuz ve Biber', 'Çay Saati', 'Babamın Gölgesi',
  'Annemin Bahçesi', 'Dedemin Saati', 'Hamsi Mevsimi', 'Üç Kardeş',
  'Yedi Tepe', 'Kırk Oda', 'Bin Bir Gece Masalı', 'Göl Evi',
  'Dağların Ardında', 'Şehir Işıkları', 'Gecenin Rengi', 'Çoban Yıldızı',
  'İki Dünya Arasında', 'Öğretmenin Defteri', 'Işıklar Sönünce',
  'Çağrı Merkezi', 'Ölü Mevsim', 'İnci Kolye', 'Şeker Bayramı',
];

const trAdjectives = <String>[
  'Kayıp', 'Sessiz', 'Son', 'Gizli', 'Karanlık', 'Kırık', 'Uzak', 'Yalnız', //
  'Derin', 'Soğuk', 'Sıcak', 'Eski', 'Yeni', 'Beyaz', 'Kara', 'Mavi',
  'Kızıl', 'Altın', 'Gümüş', 'Çılgın', 'Güzel', 'Büyük', 'Küçük', 'Masum',
  'Yasak', 'Ölümsüz', 'Unutulmuş', 'Yaralı', 'Sonsuz', 'Vahşi', 'Asi',
  'Tatlı', 'Acı', 'Uykusuz', 'Sarı', 'Yeşil', 'Mor', 'Ilık', 'Öfkeli',
  'İlk', 'Şanslı', 'Sıradışı',
];

const trNouns = <String>[
  'Şehir', 'Gece', 'Yaz', 'Kış', 'Rüya', 'Ev', 'Yol', 'Deniz', 'Dağ', //
  'Köprü', 'Sokak', 'Aşk', 'Sır', 'Kalp', 'Ayna', 'Gölge', 'Fırtına',
  'Ateş', 'Bahçe', 'Liman', 'Tren', 'Mektup', 'Çiçek', 'Kuş', 'Yıldız',
  'Saat', 'Kapı', 'Pencere', 'Hikâye', 'Düğün', 'Ağaç', 'Işık', 'Ses',
  'Yağmur', 'Kar', 'Rüzgâr', 'Ada', 'Köy', 'Kasaba', 'Mahalle', 'Konak',
  'Çarşı', 'Kervan', 'Hayalet', 'Ejderha', 'Sabah', 'Akşam', 'Bahar', 'Güz',
  'Nehir', 'Orman', 'Çöl', 'Vadi', 'Şafak', 'Kader', 'İntikam', 'Yemin',
  'Söz', 'Umut', 'Hayal', 'Öykü', 'Gerçek',
];

const trTitleSuffixes = <String>[
  ': Dönüş', ': Yeni Başlangıç', ': Son Perde', ' 2', ' 3', ': İlk Gün', //
  ': Hesaplaşma', ': Efsane',
];

const enMovieTitles = <String>[
  'The Last Harbor', 'Silent Orbit', 'Northern Lights', 'The Glass Garden', //
  'Broken Compass', 'The Quiet Hour', 'Iron Valley', 'Paper Moon Hotel',
  'The Long Road Home', 'Echoes of Winter', 'Red Horizon',
  'The Forgotten Shore', 'City of Ash', 'Blue Summer',
  'The Lighthouse Keeper', 'Wild Hearts', 'Shadow Protocol', 'Golden Hour',
  'Fallen Empire', 'The Secret Archive', 'Stormbreaker Bay',
  'The Clockmaker', 'After the Rain', 'Dark Water Creek', 'Starlight Diner',
  'The Inheritance', 'Cold Trail', 'Velvet Sky', 'The Last Dance',
  'Ghost Signal', 'The Orchard', 'Desert Bloom', 'Neon Nights',
  'The Cartographer', 'Frozen Frontier', 'Midnight Ferry', 'Salt & Smoke',
  'The Night Watchman', 'Rust Belt', 'A Quiet Place to Hide',
];

const enAdjectives = <String>[
  'Last', 'Silent', 'Dark', 'Broken', 'Hidden', 'Lost', 'Golden', 'Frozen', //
  'Crimson', 'Wild', 'Secret', 'Distant', 'Final', 'Endless', 'Burning',
  'Silver', 'Quiet', 'Fallen', 'Rising', 'Electric', 'Hollow', 'Brave',
];

const enNouns = <String>[
  'Harbor', 'Orbit', 'Garden', 'Compass', 'Valley', 'Horizon', 'Shore', //
  'Empire', 'Signal', 'Kingdom', 'River', 'Mountain', 'Island', 'Forest',
  'Bridge', 'Station', 'Frontier', 'Promise', 'Witness', 'Heist', 'Storm',
  'Echo', 'Legacy', 'Code', 'Mission', 'Summer', 'Winter', 'Night', 'Road',
  'Dream', 'Tide', 'Crown',
];

const enTitleSuffixes = <String>[
  ' II', ' 2', ': Reckoning', ': The Return', ': Origins', ' Rising', //
  ': Final Chapter',
];

const itMovieTitles = <String>[
  'La Notte Lunga', 'Il Ritorno', "Cinque Giorni d'Estate", //
  'La Città Perduta', 'Il Segreto del Lago', 'Ultimo Treno per Napoli',
  'La Casa sul Mare', 'Perché No?', 'Così Lontano', 'La Verità Nascosta',
  'Il Giardino dei Ricordi', 'Amore e Caffè', 'La Strada Bianca',
  "Il Silenzio dell'Isola", 'Notte di Luna', 'La Voce del Vento',
  'Più Forte del Destino', 'Il Viaggio di Marco', 'Tre Sorelle',
  'La Dolce Estate', 'Caffè Sospeso', 'Città di Vetro',
];

const itMascNouns = <String>[
  'Viaggio', 'Ritorno', 'Segreto', 'Silenzio', 'Mare', 'Cielo', //
  'Giardino', 'Treno', 'Sogno', 'Destino', 'Inverno',
];
const itFemNouns = <String>[
  'Notte', 'Città', 'Strada', 'Casa', 'Estate', 'Verità', 'Luna', 'Voce', //
  'Isola', 'Promessa', 'Montagna',
];

/// Masculine / feminine adjective forms.
const itAdjectives = <List<String>>[
  ['Perduto', 'Perduta'], ['Nascosto', 'Nascosta'], ['Lungo', 'Lunga'], //
  ['Bianco', 'Bianca'], ['Nero', 'Nera'], ['Dolce', 'Dolce'],
  ['Felice', 'Felice'], ['Eterno', 'Eterna'], ['Segreto', 'Segreta'],
  ['Freddo', 'Fredda'], ['Ultimo', 'Ultima'],
];

const deMovieTitles = <String>[
  'Die stille Stadt', 'Der letzte Zug', 'Das dunkle Haus', //
  'Schöne Grüße aus Köln', 'Die Brücke am Fluss', 'Der Fall Müller',
  'Nächte in München', 'Grüße vom Nordpol', 'Die Insel der Träume',
  'Das Erbe', 'Über den Wolken', 'Heimweh nach Hamburg', 'Die Spur im Schnee',
  'Mörderische Wahrheit', 'Fräulein Doktor', 'Das große Glück',
  'Kältewelle', 'Die süße Rache', 'Der Bäcker von Würzburg',
  'Zwölf Tage im Mai',
];

const deMascNouns = <String>[
  'Zug', 'Sommer', 'Winter', 'Wald', 'Fluss', 'Traum', 'Weg', 'Himmel', //
  'Mann', 'Schatten', 'Sturm',
];
const deFemNouns = <String>[
  'Stadt', 'Nacht', 'Reise', 'Grenze', 'Insel', 'Brücke', 'Straße', //
  'Wahrheit', 'Spur', 'Stille', 'Küste',
];
const deNeutNouns = <String>[
  'Haus', 'Dorf', 'Herz', 'Licht', 'Spiel', 'Geheimnis', 'Erbe', 'Ufer', //
  'Schloss', 'Glück',
];

/// Adjective stems already declined for `der/die/das` (weak declension).
const deAdjectives = <String>[
  'letzte', 'stille', 'dunkle', 'große', 'kleine', 'kalte', 'schöne', //
  'verlorene', 'geheime', 'weiße', 'schwarze', 'grüne', 'müde', 'böse',
  'süße', 'heiße', 'fröhliche',
];

const trSeriesTitles = <String>[
  'Aile Sırları', 'Mahalle Arası', 'Kayıp Yıllar', 'Yeşil Vadi', //
  'Bizim Konak', 'Kızıl Gökyüzü', 'Rüzgârın Kızı', 'Saklı Bahçe',
  'Kader Yolu', 'Sevdam Ankara', 'İstanbul Masalı', "Ege'nin Kızı",
  'Uzak Şehir', 'Gölgedeki Aşk', 'Çarşı Kapısı', 'Kırık Hayaller',
  'Son Nöbet', 'Şehrin Kalbi', 'Doktorlar Koridoru', 'Kuzey Rüzgârı',
  'Avcılar', 'Yalı Kızları', 'Kuyu', 'Teşkilat Dosyası', 'Pera Palas Gizemi',
  'Soğuk Savaş Çocukları', 'İhtişam', 'Mavi Kapı', 'Karagöz Sokağı',
  'Yaz Kampı', 'Öğretmenler Odası', 'Şirket', 'Kervan Yolu',
  'Fırtınalı Yıllar', 'Gönül Köprüsü', 'Ağaçlar Ölmez', 'Çamlıca Konağı',
];

const trSeriesSuffixes = <String>[
  ' Günlükleri', ' Dosyası', ' Ailesi', ' Yılları', ' Sokağı', ' Efsanesi', //
];

const enSeriesTitles = <String>[
  'The Night Shift Files', 'Harbour Street', 'The Inspector', //
  'Cold Case Unit', 'Northern Watch', 'The Glass House', 'Kingdom of Sand',
  'The Outpost Station', 'Silicon Dreams', 'Brightwater', 'Dark Meridian',
  'Red Line', 'The Long Winter', 'Starfall', 'The Tutor', 'Blue Lagoon Hotel',
  'Code Black Ward', 'The Ferryman', 'Westwood Academy', 'Small Town Secrets',
];

const enSeriesSuffixes = <String>[
  ' Chronicles', ' Files', ' Diaries', ' Stories', ' Unit', ' Legacy', //
];

const itSeriesTitles = <String>[
  'Il Commissario Rossi', 'Medici in Corsia', 'Un Posto al Mare', //
  'La Famiglia Conti', 'Notti di Napoli', 'Il Paese delle Meraviglie',
];

const deSeriesTitles = <String>[
  'Kommissar Weber', 'Die Klinik am See', 'Familie Schröder', //
  'Großstadtrevier Nord', 'Dahoam im Dorf', 'Die Küstenwache',
];

// ---------------------------------------------------------------------------
// People
// ---------------------------------------------------------------------------

const trFirstNames = <String>[
  'Ayşe', 'Mehmet', 'Zeynep', 'Can', 'Elif', 'Burak', 'Selin', 'Emre', //
  'Deniz', 'Ece', 'Ozan', 'Gökçe', 'İrem', 'Barış', 'Cem', 'Defne', 'Tolga',
  'Melis', 'Kerem', 'Pınar', 'Umut', 'Serkan', 'Gizem', 'Yiğit', 'Duru',
  'Onur', 'Ebru', 'Murat', 'Aslı', 'Hakan', 'Özge', 'Sinan', 'Ceren', 'Berk',
  'Şule', 'Lale', 'Tuncay', 'Çağla', 'Kaan', 'Seda', 'Volkan', 'Ilgın',
  'Ömer', 'Rüya', 'Tarık', 'Cemal', 'Hülya', 'Şebnem', 'Güneş', 'Ufuk',
  'Gül', 'İlker', 'Oya', 'Bülent',
];

const trLastNames = <String>[
  'Yılmaz', 'Öztürk', 'Çelik', 'Aydın', 'Şahin', 'Doğan', 'Arslan', 'Koç', //
  'Kaya', 'Güneş', 'Kılıç', 'Aksoy', 'Özdemir', 'Yıldız', 'Şimşek', 'Kurt',
  'Polat', 'Avcı', 'Uçar', 'Çakır', 'Aktaş', 'Bulut', 'Turan', 'Karaca',
  'Ekinci', 'Tekin', 'Sarı', 'Güler', 'Erdem', 'Işık', 'Uysal', 'Akın',
  'Toprak', 'Keskin', 'Ünal', 'Öz', 'Bayram', 'Altun', 'Yücel', 'Esen',
  'Duman', 'Kara', 'Başaran', 'Ilgaz', 'Sözer', 'Tunç', 'Ateş', 'Çınar',
  'Gündoğdu', 'Özkan',
];

const enFirstNames = <String>[
  'James', 'Emily', 'Michael', 'Sarah', 'Daniel', 'Olivia', 'Thomas', //
  'Grace', 'William', 'Charlotte', 'Henry', 'Amelia', 'Jack', 'Sophie',
  'George', 'Lucy', 'Oliver', 'Hannah', 'Samuel', 'Chloe',
];

const enLastNames = <String>[
  'Carter', 'Hayes', 'Brooks', 'Mitchell', 'Foster', 'Bennett', 'Reed', //
  'Turner', 'Collins', 'Morgan', 'Parker', 'Ellis', 'Hughes', 'Ward', 'Price',
  'Fletcher', 'Walsh', 'Harper', 'Doyle', 'Quinn',
];

const itFirstNames = <String>[
  'Marco', 'Giulia', 'Luca', 'Francesca', 'Alessandro', 'Chiara', 'Matteo', //
  'Sofia', 'Lorenzo', 'Elena', 'Niccolò', 'Bianca',
];

const itLastNames = <String>[
  'Rossi', 'Bianchi', 'Ferrari', 'Romano', 'Conti', 'Galli', 'Ricci', //
  'Marino', 'Greco', 'Bruno', 'Colombo', 'De Luca', 'Fabbri', 'Mancini',
];

const deFirstNames = <String>[
  'Lukas', 'Anna', 'Jonas', 'Lea', 'Felix', 'Marie', 'Maximilian', //
  'Sophie', 'Jürgen', 'Jörg', 'Ute', 'Björn', 'Lena', 'Paul',
];

const deLastNames = <String>[
  'Müller', 'Schröder', 'Weiß', 'Köhler', 'Groß', 'Bäcker', 'Würth', //
  'Jäger', 'Schäfer', 'Krüger', 'Hoffmann', 'Wagner', 'Fuchs', 'Lehmann',
];

// ---------------------------------------------------------------------------
// Plots
// ---------------------------------------------------------------------------

const trRoles = <String>[
  'genç bir öğretmen', 'emekli bir polis', 'hırslı bir avukat', //
  'yalnız bir ressam', 'başarısız bir yazar', 'idealist bir doktor',
  'eski bir boksör', 'meraklı bir gazeteci', 'genç bir aşçı',
  'yetenekli bir hacker', 'inatçı bir dedektif', 'sessiz bir balıkçı',
];

const trEvents = <String>[
  'geçmişinden gelen gizemli bir mektupla sarsılır', //
  'kayıp kardeşini aramaya başlar', 'beklenmedik bir mirasa konar',
  'eski bir dostunun ölümünü araştırır',
  'hayatını değiştirecek bir teklif alır',
  'şehrin en büyük sırrına ortak olur',
  'kendini bir anda kaçak durumunda bulur',
  'çocukluk aşkıyla yeniden karşılaşır',
  'ailesinin borçlarını ödemek için tehlikeli bir işe girer',
  'kasabadaki tuhaf olayların peşine düşer',
];

const trTwists = <String>[
  'Gerçekler ortaya çıktıkça hiçbir şey eskisi gibi olmayacaktır.', //
  'Zamanla yarışırken kendi sınırlarını keşfeder.',
  'Ancak herkesin saklayacak bir şeyi vardır.',
  'Bu yolculuk ona affetmeyi yeniden öğretir.',
  'Kimin dost kimin düşman olduğunu anlamak için çok az zamanı vardır.',
  'Kahkaha ve gözyaşının iç içe geçtiği sıcak bir hikâye.',
];

const enRoles = <String>[
  'a young teacher', 'a retired detective', 'an ambitious lawyer', //
  'a lonely painter', 'a struggling writer', 'an idealistic doctor',
  'a former boxer', 'a curious reporter', 'a gifted hacker',
  'a stubborn fisherman',
];

const enEvents = <String>[
  'receives a mysterious letter from the past', //
  'starts searching for a missing sister', 'inherits a crumbling hotel',
  "investigates an old friend's death", 'gets an offer that changes everything',
  "uncovers the town's best kept secret",
  'suddenly finds themselves on the run',
];

const enTwists = <String>[
  'As the truth comes out, nothing will ever be the same.', //
  'Racing against time, they discover their own limits.',
  'But everyone in town has something to hide.',
  'A warm story about family, forgiveness and second chances.',
  'Trust is the one thing they cannot afford.',
];

const itPlots = <String>[
  'Un giovane insegnante torna nella sua città natale e scopre un segreto di famiglia.', //
  'Due sorelle ereditano una villa sul lago, ma la verità è più complicata del previsto.',
  'Un commissario ostinato indaga su una serie di furti misteriosi a Napoli.',
  "Un'estate al mare cambia per sempre la vita di tre amici.",
];

const dePlots = <String>[
  'Eine junge Ärztin zieht aufs Land und gerät in ein Netz aus alten Lügen.', //
  'Ein pensionierter Kommissar rollt einen ungelösten Fall noch einmal auf.',
  'Zwei Brüder erben eine Bäckerei in Würzburg – und jede Menge Ärger.',
  'Ein Sommer an der Küste verändert das Leben einer Familie für immer.',
];

// ---------------------------------------------------------------------------
// Genres and categories
// ---------------------------------------------------------------------------

const trGenres = <String>[
  'Aksiyon', 'Komedi', 'Dram', 'Bilim Kurgu', 'Belgesel', 'Korku', //
  'Gerilim', 'Romantik', 'Animasyon', 'Aile', 'Fantastik', 'Macera', 'Suç',
  'Tarih', 'Savaş', 'Müzikal', 'Gizem', 'Biyografi',
];

const enGenres = <String>[
  'Action', 'Comedy', 'Drama', 'Science Fiction', 'Documentary', 'Horror', //
  'Thriller', 'Romance', 'Animation', 'Family', 'Fantasy', 'Adventure',
  'Crime', 'History', 'War', 'Mystery',
];

const trCountries = <String>['Türkiye', 'Türkiye', 'Türkiye', 'Almanya'];
const enCountries = <String>[
  'United Kingdom',
  'United States',
  'Canada',
  'Ireland',
];

const ageRatings = <String>['Genel İzleyici', '7+', '13+', '16+', '18+'];

// ---------------------------------------------------------------------------
// Programme guide
// ---------------------------------------------------------------------------

/// Programme titles per language and genre. `{A}`/`{B}` are team names,
/// `{M}` is a movie title.
const programmeTitles = <String, Map<String, List<String>>>{
  'tr': {
    'news': [
      'Ana Haber', 'Sabah Haberleri', 'Gün Ortası', 'Akşam Haberleri', //
      'Gece Haberleri', 'Haber Saati', 'Ekonomi Gündemi', 'Dünya Bülteni',
      'Spor Haberleri', 'Hava Durumu', 'Tartışma Masası', 'Gündem Özel',
      'Haftanın Özeti', 'Bölge Haberleri', 'Teke Tek Röportaj',
      'Piyasa Kapanış', 'Manşet', 'Haber Merkezi',
    ],
    'general': [
      'Sabah Kuşağı', 'Gün Işığı', 'Yemek Zamanı', 'Kim Kazanacak?', //
      'Bilgi Yarışması', 'Hafta Sonu Keyfi', 'Pazar Sohbetleri', 'Sağlık Saati',
      'Komedi Gecesi', 'Magazin Ekspres', 'Kafa Dengi', 'Evim Şahane',
      'Gelin & Kaynana',
    ],
    'series': [
      'Kayıp Yıllar', 'Aile Sırları', 'Mahalle Arası', 'Yeşil Vadi', //
      'Bizim Konak', 'Kızıl Gökyüzü', 'Rüzgârın Kızı', 'Saklı Bahçe',
      'Kader Yolu', 'İstanbul Masalı', "Ege'nin Kızı", 'Uzak Şehir',
      'Sıcak Kafa', 'Gölgedeki Aşk',
    ],
    'sports': [
      'Maç Önü', 'Maç Sonu', 'Spor Gündemi', 'Futbol Keyfi', //
      'Canlı Maç: {A} - {B}', 'Basketbol Süper Ligi: {A} - {B}',
      'Voleybol: {A} - {B}', 'Golün Hikâyesi', 'Spor Ekranı',
      'Formula 1 Özet', 'Haftanın Golleri', 'Taraftar Masası',
      'Sporun Efsaneleri',
    ],
    'docs': [
      'Vahşi Doğa', "Anadolu'nun Gizemleri", 'Okyanus Derinlikleri', //
      'Tarihin İzinde', 'Kayıp Medeniyetler', 'Uzayın Sırları', 'Büyük Göç',
      'Yaban Hayatı', 'Mühendislik Harikaları', 'Şehirlerin Hikâyesi',
      'Doğanın Mucizeleri', 'Kuşların Dünyası', 'Antik Kentler',
      'Lezzet Durakları',
    ],
    'kids': [
      'Minik Kaşifler', 'Uzay Kedisi', 'Renkli Orman', 'Çizgi Saat', //
      'Masal Ağacı', 'Robot Ali', 'Küçük Sincap', 'Kardan Adam Kuki',
      'Neşeli Çiftlik', 'Sihirli Kalem', 'Denizaltı Macerası', 'Uçan Halı',
      'Dinozor Dostlar', 'Bilmece Bulmaca',
    ],
    'movies': ['Gece Sineması: {M}', 'Film: {M}', '{M}', 'Yerli Film: {M}'],
    'music': [
      'Hit Listesi', 'Klip Saati', 'Türkçe Pop', 'Akustik Gece', //
      'Nostalji Şarkıları', 'Canlı Performans', 'Top 20', 'Yeni Çıkanlar',
      'Sabah Melodileri', 'Arabesk Saati',
    ],
    'local': [
      'Yerel Haberler', 'Şehir Gündemi', 'Belediye Saati', 'Esnaf Sohbeti', //
      'Yöresel Lezzetler', 'Halk Müziği', 'Köy Hayatı', 'Bölge Sporu',
      'Kent Rehberi',
    ],
  },
  'en': {
    'news': [
      'Breakfast News', 'The News at Six', 'Newsnight', //
      'World Business Report', 'Politics Live', 'Weather', 'Sportsday',
      'The Briefing', 'Global Headlines', 'Evening Bulletin',
    ],
    'general': [
      'Morning Live', 'Countryside Diaries', 'Quiz Night', 'Home Fixers', //
      'The Great Bake', 'Antiques Hunt', 'Escape to the Coast',
      'Comedy Club', 'Garden Rescue', 'Car Swap & Shop',
    ],
    'series': [
      'Murder in the Valley', 'Harbour Street', 'The Inspector', //
      'Cold Case Files', 'Doctors on Call', 'Northern Watch',
      'The Glass House',
    ],
    'sports': [
      'Football Tonight: {A} v {B}', 'Premier Football: {A} v {B}', //
      'Match of the Week', 'Cricket: {A} v {B}', 'Golf: Open Highlights',
      'Rugby: {A} v {B}', 'Boxing Night', 'F1 Grand Prix Highlights',
      'Sports Centre', 'Racing Live',
    ],
    'docs': [
      'Planet Wild', 'Ocean Giants', 'Lost Civilisations', //
      'Mega Structures', 'The Universe Explained', 'Into the Jungle',
      'Ancient Engineers', 'Arctic Life', 'Wild Britain',
      'Secrets of the Museum',
    ],
    'kids': [
      'Space Pals', 'Little Explorers', 'Rainbow Forest', 'Robot Riley', //
      'Tiny Dinos', 'Story Time', 'The Magic Pencil', 'Pirate Pups',
    ],
    'movies': ['{M}', 'Film: {M}', 'Movie Premiere: {M}'],
    'music': ['Top 40 Countdown', 'Classic Hits', 'Live Lounge', 'Indie Hour'],
    'local': ['Local News', 'Town Hall', 'Community Matters', 'Regional Sport'],
  },
  'it': {
    'news': [
      'Telegiornale', 'TG Sera', 'TG Mattina', 'Meteo', 'Linea Notte', //
      'Speciale TG', 'Economia Oggi',
    ],
    'general': [
      'Il Mattino in Famiglia', 'Cucina Italiana', 'Quiz Serale', //
      'La Grande Sfida', 'Viaggio in Italia', 'Notte Comica',
    ],
    'series': [
      'Il Commissario Rossi', 'Medici in Corsia', 'Un Posto al Mare', //
      'La Famiglia Conti',
    ],
    'sports': [
      'Calcio Serie A: {A} - {B}', 'Gol Gol Gol', 'Pressing', //
      'Basket: {A} - {B}', 'MotoGP Sintesi', 'Ciclismo: Tappa del Giorno',
    ],
    'docs': [
      'Natura Selvaggia', 'Le Vie della Storia', 'Mondi Sommersi', //
      "Città d'Arte",
    ],
    'kids': [
      'Le Avventure di Pippo', 'Il Piccolo Esploratore', 'Cartoni Magici', //
    ],
    'movies': ['{M}', 'Film: {M}'],
    'music': ['Hit Parade', 'Musica Live'],
    'local': ['Notizie Locali', 'La Città Oggi'],
  },
  'de': {
    'news': [
      'Nachrichten am Abend', 'Morgenmagazin', 'Mittagsmagazin', 'Wetter', //
      'Abendjournal', 'Die Reportage', 'Wirtschaft Kompakt',
    ],
    'general': [
      'Küchenzauber', 'Quizshow am Abend', 'Gärten im Glück', //
      'Abenteuer Alltag', 'Volle Kanne', 'Hallo Nachbar',
    ],
    'series': [
      'Die Klinik am See', 'Kommissar Weber', 'Familie Schröder', //
      'Großstadtrevier Nord', 'Dahoam im Dorf',
    ],
    'sports': [
      'Fußball: {A} - {B}', 'Sportschau Kompakt', 'Bundesliga Highlights', //
      'Handball: {A} - {B}', 'Formel 1: Rennen', 'Wintersport Live',
    ],
    'docs': [
      'Wildes Deutschland', 'Terra Mystica', 'Expedition Erde', //
      'Geheimnisse der Geschichte', 'Planet Ozean',
    ],
    'kids': ['Kleine Entdecker', 'Lilos Abenteuer', 'Die Bärenbande'],
    'movies': ['{M}', 'Spielfilm: {M}'],
    'music': ['Hitparade', 'Schlager am Abend'],
    'local': ['Regionalnachrichten', 'Stadtgespräch'],
  },
};

const teamNames = <String, List<String>>{
  'tr': [
    'Anadolu Kartalları', 'Boğaziçi SK', 'Ege Yıldızları', 'Karadeniz FK', //
    'Başkent Gücü', 'Çukurova Spor', 'Marmara Gençlik', 'Toros SK',
    'Kapadokya FK', 'Fırat Spor',
  ],
  'en': [
    'Northbridge United', 'Riverside Rovers', 'Kingsport City', //
    'Harbour Athletic', 'Westfield Town', 'Oakham Wanderers',
  ],
  'it': [
    'Atletico Laguna',
    'Sporting Vesuvio',
    'Real Appennino',
    'Virtus Lago',
  ],
  'de': [
    'FC Rheinufer', 'SV Bergland', 'Eintracht Nordsee', 'TSV Alpenblick', //
    'Borussia Talheim',
  ],
};

/// Programme category labels per language and genre.
const programmeCategories = <String, Map<String, String>>{
  'tr': {
    'news': 'Haber',
    'general': 'Eğlence',
    'series': 'Dizi',
    'sports': 'Spor', //
    'docs': 'Belgesel', 'kids': 'Çocuk', 'movies': 'Film', 'music': 'Müzik',
    'local': 'Yerel',
  },
  'en': {
    'news': 'News', 'general': 'Entertainment', 'series': 'Drama', //
    'sports': 'Sports', 'docs': 'Documentary', 'kids': 'Children',
    'movies': 'Movie', 'music': 'Music', 'local': 'Local',
  },
  'it': {
    'news': 'Notizie', 'general': 'Intrattenimento', 'series': 'Fiction', //
    'sports': 'Sport', 'docs': 'Documentario', 'kids': 'Bambini',
    'movies': 'Film', 'music': 'Musica', 'local': 'Locale',
  },
  'de': {
    'news': 'Nachrichten', 'general': 'Unterhaltung', 'series': 'Serie', //
    'sports': 'Sport', 'docs': 'Dokumentation', 'kids': 'Kinder',
    'movies': 'Spielfilm', 'music': 'Musik', 'local': 'Regional',
  },
};

const episodeWord = <String, String>{
  'tr': 'Bölüm',
  'en': 'Episode',
  'it': 'Episodio',
  'de': 'Folge',
};

/// Short programme descriptions per language (no plot slots, so the guide
/// generator can reuse pre-escaped strings).
const programmeDescriptions = <String, List<String>>{
  'tr': [
    'Günün öne çıkan gelişmeleri ve canlı bağlantılar.', //
    'Uzman konuklarla gündemin perde arkası.',
    'Sevilen dizinin yeni bölümünde ilişkiler iyice karışıyor.',
    'Ailece izlenecek eğlenceli bir program.',
    'Doğanın en etkileyici görüntüleri bu belgeselde.',
    'Haftanın en heyecanlı karşılaşması canlı yayında.',
    'Minik izleyiciler için renkli ve öğretici maceralar.',
    'Yerel lezzetler ve unutulmaya yüz tutmuş tarifler.',
    'Şehrin dört bir yanından haberler ve röportajlar.',
    'Ödüllü yönetmenin merakla beklenen filmi ilk kez ekranda.',
  ],
  'en': [
    'The day’s top stories with live reports.', //
    'Experts discuss the headlines behind the headlines.',
    'Tensions rise in a brand-new episode of the hit drama.',
    'Light-hearted entertainment for the whole family.',
    'Breathtaking wildlife footage from around the globe.',
    'Live coverage of the biggest match of the week.',
    'Colourful adventures for younger viewers.',
    'A celebrated film, shown for the first time on TV.',
  ],
  'it': [
    'Le notizie del giorno con collegamenti in diretta.', //
    'Una serata di intrattenimento per tutta la famiglia.',
    'La grande partita in diretta con commento e analisi.',
    'Viaggio tra le meraviglie della natura italiana.',
  ],
  'de': [
    'Die wichtigsten Nachrichten des Tages im Überblick.', //
    'Unterhaltung für die ganze Familie.',
    'Das Spitzenspiel der Woche live mit Analyse.',
    'Faszinierende Bilder aus der Natur.',
  ],
};
