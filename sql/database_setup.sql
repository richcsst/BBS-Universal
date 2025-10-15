-- Create a fresh and new database

DROP DATABASE IF EXISTS BBSUniversal;
CREATE DATABASE BBSUniversal CHARACTER SET utf8;
USE BBSUniversal;

-- Type | Maximum length
-- -----------+-------------------------------------
--   TINYTEXT |           255 bytes
--       TEXT |        65,535 bytes = 64 KiB
-- MEDIUMTEXT |    16,777,215 bytes = 16 MiB
--   LONGTEXT | 4,294,967,295 bytes =  4 GiB

-- Tables

CREATE TABLE config (
    config_name  VARCHAR(255) PRIMARY KEY,
    config_value VARCHAR(255)
);

CREATE TABLE text_modes (
    id        TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    text_mode ENUM('ASCII','ATASCII','PETSCII','ANSI')
);

CREATE TABLE users (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    username        VARCHAR(32) NOT NULL,
    password        CHAR(128) NOT NULL,
    given           VARCHAR(255) NOT NULL,
    family          VARCHAR(255) NOT NULL,
    nickname        VARCHAR(255),
    email           VARCHAR(255) DEFAULT '',
    max_columns     SMALLINT UNSIGNED DEFAULT 80,
    max_rows        SMALLINT UNSIGNED DEFAULT 25,
    accomplishments TEXT,
    retro_systems   TEXT,
    birthday        DATE,
    date_format     CHAR(14) DEFAULT 'YEAR/MONTH/DAY',
    file_category   INT UNSIGNED NOT NULL DEFAULT 1,
    forum_category  INT UNSIGNED NOT NULL DEFAULT 1,
    location        VARCHAR(255),
    baud_rate       ENUM('FULL','19200','9600','4800','2400','1200','300') NOT NULL DEFAULT '2400',
    access_level    ENUM('USER','VETERAN','JUNIOR SYSOP','SYSOP') NOT NULL DEFAULT 'USER',
    login_time      TIMESTAMP NOT NULL DEFAULT NOW(),
    logout_time     TIMESTAMP NOT NULL DEFAULT NOW(),
    text_mode       TINYINT UNSIGNED NOT NULL
);

CREATE TABLE permissions (
    id              INT UNSIGNED PRIMARY KEY,
    show_email      BOOLEAN DEFAULT FALSE,
    view_files      BOOLEAN DEFAULT FALSE,
    upload_files    BOOLEAN DEFAULT FALSE,
    download_files  BOOLEAN DEFAULT FALSE,
    remove_files    BOOLEAN DEFAULT FALSE,
    read_message    BOOLEAN DEFAULT FALSE,
    post_message    BOOLEAN DEFAULT FALSE,
    remove_message  BOOLEAN DEFAULT FALSE,
    sysop           BOOLEAN DEFAULT FALSE,
    page_sysop      BOOLEAN DEFAULT TRUE,
    prefer_nickname BOOLEAN DEFAULT FALSE,
    play_fortunes   BOOLEAN DEFAULT FALSE,
	banned          BOOLEAN DEFAULT FALSE,
    timeout         SMALLINT UNSIGNED DEFAULT 10
);

CREATE TABLE message_categories (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    access_level ENUM('USER', 'VETERAN', 'JUNIOR SYSOP','SYSOP') NOT NULL DEFAULT 'USER',
    name        VARCHAR(255) NOT NULL,
    description TEXT NOT NULL
);

CREATE TABLE messages (
    id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    category INT UNSIGNED NOT NULL,
    from_id  INT UNSIGNED NOT NULL,
    title    VARCHAR(255) NOT NULL,
    hidden   BOOLEAN DEFAULT FALSE,
    message  TEXT NOT NULL,
    created  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE rss_feed_categories (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	title       VARCHAR(255) NOT NULL,
    description VARCHAR(255) NOT NULL,
);

CREATE TABLE rss_feeds (
    id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	category INT UNSIGNED NOT NULL,
	title    VARCHAR(255) NOT NULL,
	url      VARCHAR(255) NOT NULL
);

CREATE TABLE file_categories (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    title       VARCHAR(255) NOT NULL,
    description TEXT
);

CREATE TABLE files (
    id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    filename     VARCHAR(255) NOT NULL,
    title        VARCHAR(255) NOT NULL,
    user_id      INT UNSIGNED NOT NULL DEFAULT 1,
    category     INT UNSIGNED NOT NULL DEFAULT 1,
    file_type    SMALLINT NOT NULL,
    description  TEXT NOT NULL,
    file_size    BIGINT UNSIGNED NOT NULL,
    uploaded     TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    endorsements INT UNSIGNED DEFAULT 0
);

CREATE TABLE file_types (
    id        SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    type      VARCHAR(255),
    extension VARCHAR(5)
);

CREATE TABLE bbs_listing (
    bbs_id        INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    bbs_name      VARCHAR(255) NOT NULL,
    bbs_hostname  VARCHAR(255) NOT NULL,
    bbs_port      SMALLINT UNSIGNED DEFAULT 9999,
    bbs_poster_id INT UNSIGNED NOT NULL
);

CREATE TABLE news (
    news_id      INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    news_date    TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    news_title   VARCHAR(255),
    news_content TEXT
);

-- Inserts

INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ('BBS Universal Sample','localhost',9999,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("13th Floor BBS","13th.hoyvision.com",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("13th Leader BBS","13leader.net",8023,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("1992 BBS","98.113.13.134",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("20 For Beers BBS","20forbeers.com",1337,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("300 F-ing Baud BBS","300baud.dynu.net",2525,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("32-Bit BBS","x-bit.org",23230,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("3D Realms","172.0.79.226",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("4 Wheel Ham BBS","bbs.4wheelham.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("4D2 Dot Org","bbs.4d2.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("64 Vintage BBS","64vintageremixbbs.dyndns.org",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("68k Mac Club","bbs.m68k.club",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("8-Bit Archive","bbs.8-bitarchive.com",2223,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("8-Bit Boyz BBS","bbs.8bitboyz.com",6502,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("8-bit Misfits","www.brokenbit.us",8888,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("8-Bit Playground","8bit.hoyvision.com",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("8Bit Club BBS","bbs.8bitclub.com",6502,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("A-Net Online (Game Server)","game.a-net-online.lol",513,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("A-Net Online (Linux Synchronet)","x.a-net.online",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("A-Net Online (Mystic)","mystic-anet.online",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("A-Net Online (Spitfire)","sf.a-net.online",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("A-Net Online (Synchronet)","a-net.online",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("A-Net Online (TWGS)","game.a-net-online.lol",2002,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("A1 BBS","a1bbs.ddns.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Absinthe BBS","absinthebbs.net",1940,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Abyss BBS","bbs.abyssnode.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Ace of Spades BBS","chaotix.ddns.net",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Acid Underworld","blackflag.acid.org",31337,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("ACS BBS","18.205.154.92",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Adept BBS TWGS","adeptbbs.com",2002,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Adept Online Entertainment","adeptbbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Aerodrome","theaerodromebbs.com",6502,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Agency BBS","agency.bbs.nz",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Agon BBS","krion.io",1337,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Agster","bbs.aghy.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Aincrad BBS","67.205.168.255",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Air & Wave BBS","bbs.airandwave.net",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Al's Geek Lab BBS","bbs.alsgeeklab.com",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Alcatraz Prison BBS","alcatrazbbs.ddns.net",9000,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Alcoholiday BBS (Mystic)","alcoholidaybbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Alcoholiday BBS (Renegade)","alcoholidaybbs.com",95,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Ale's BBS","manalejandro.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Aleco Experience BBS","bbs.alecoexp.cz",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Alien Mindbenders BBS","195.43.155.90",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Aliens' Alcove!","aliens.ph",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Alltsk","fido.alltsk.ru",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Alpha Centauri BBS","acentauribbs.no-ip.org",2002,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Alpha Complex","www.alphacomplex.us",2523,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Alphachron BBS","193.22.2.193",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("AlphaNet","2.236.17.38",2888,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("ALT119","bbs.alt119.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Altair IV BBS","altairiv.ddns.net",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Altair Mini BBS","altairminibbs.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Altar of Wares","altarofwaresbbs.hopto.org",6464,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Alterant BBS","115.70.188.112",123,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("American Connection BBS","tacbbs.synchro.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Amiga CBM BBS","amiganer.amms-bbs.de",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Amiga City","amigacity.xyz",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Amiga Retro Brisbane BBS","www.amigaretro.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Amiga Retro V4SA BBS","amibbs.amigaretro.com",6880,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Amiga Underground (AmiExpress)","amigaunderground.com",2300,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Amis XE","amis86.ddns.net",9000,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("AMSTRAD BBS","amstrad.simulant.uk",464,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Analog Waffle","waffle.c4bmore.com",2001,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Anduin BBS","bbs.anduin.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Animation Game Station (Animeyo)","54.238.90.108",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Another Droid BBS","andr01d.zapto.org",9999,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Another F-ing BBS","anotherbbs.dynu.net",1337,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("ANSITex","115.70.188.112",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Antelope Love BBS","bbs.antelopelovefan.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Anti Earth Union Government (Chinese)","125.229.104.182",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Antidote","antidote.triad.se",64128,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Antikitera","technotron.asuscomm.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Anybox BBS","anybox.freedyndns.de",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Arcadia BBS (1)","bbs.arcadiabbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Arcadia BBS (2)","www.mythicalhosting.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Archaic Binary","bbs.archaicbinary.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("ArcticZone Online Entertainment (1)","bbs.arcticzonebbs.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("ArcticZone Online Entertainment (2)","bbs2.arcticzonebbs.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("ARDA-BBS.com","arda-bbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Area 52","area52.tk",5200,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Arena BBS","netasylum.com",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Ariana Interface","ariana.synchro.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("ARTNET","50.116.51.149",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("AT2K Design BBS","bbs.at2k.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Atari Portfolio BBS (POFOBBS)","pofobbs.ddns.net",992,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Atavachron BBS","bbs.atavachronbbs.net",22,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Athelstan BBS","athelstan.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Atlantis BBS","75.8.224.32",6401,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Atmosphere BBS (NTU)","bbs.as.ntu.edu.tw",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Attic BBS","theattic.v1cd3m1z3r.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Avalon Isle BBS","atl.ddns.net",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Avast! BBS","avastbbs.servegame.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Avogodro BBS","137.184.181.34",8888,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Baba Yaga's BBS","68.98.101.79",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Back In Time","backintime.ddns.net",6510,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Back to the Future (SSH)","bttfbbs.com",22,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Backwood Realm BBS","bwrbbs.ddns.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Baffa BBS","baffa.zapto.org",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Bahamut BBS","bbs.gamer.com.tw",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Barbaria (SSH)","barbaria.norbus.com",22,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Basement BBS","basementbbs.ddns.net",9000,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Bass Planet","thebassplanet.com",64128,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Baudville","amis86.ddns.net",9000,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Bayou BBS","jayctheriot.com",6401,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("BBS Development","bbsdev.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("BBS GameTime (MajorBBS)","freespeak.hopto.org",1337,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("BBS GameTime (Menu)","freespeak.hopto.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("BBS GameTime (PCBoard)","freespeak.hopto.org",233,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("BBS GameTime (Synchronet)","freespeak.hopto.org",23233,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("BBS Is Cool","bbsiscool.emailisstupid.com",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("BBS OldChat","bbs.oldchat.ru",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("BBS Orreli","bbs.orreli.net",45023,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("BBS Retrocampus","bbs.retrocampus.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("BBS Tournament Wordle","bbswordle.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("BBS.Telearena.us","bbs.telearena.us",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("BCG-Box","bbbs.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("BCR Games Server","bcrgames.com",31337,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Bear's Den","bbs.bearfather.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Beckinsdale","76.213.177.217",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("BeeBS II","beebs.ddns.net",6502,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("BEER-ISAC BBS","31.220.63.185",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Beiyou Forum","bbs.byr.cn",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Big Rabbit BBS","bunnybbs.tw",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Big Time BBS","bigtimebbs.net",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Big5 BBS","39.106.161.147",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Biker Bob's Clubhouse","bbsclubhouse.ddns.net",1040,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("BirdEnuf BBS","bbs.birdenuf.com",2003,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("BitPlane BBS","wa7npx.org",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Bitpunk BBS","bbs.bitpunk.fm",8888,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Bits & Bytes BBS","bbs.bnbbbs.net",2023,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Bitwoods RBBS-PC","bitwoods.duckdns.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Black Flag BBS","blackflag.acid.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Black Tower BBS","blackflag.acid.org",26,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("BlackICE","88.153.40.209",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Blacklight Underground","acentauribbs.no-ip.org",2424,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Blackstar BBS","blackstar-bbs.servegame.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Blood Stone","wwiv.bsbbs.com",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Blood Storm","bstorm.synchro.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("BLOODBBS","blood.bbsn.us",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Blue Wave BBS","110.232.113.108",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Boar's Head Tavern","byob.hopto.org",64128,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("BodaX BBS","bbs.beardy.se",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Boebertfeet","66.228.38.176",52270,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("BoobTube","bbs.wz5bbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Books Chess Server","books.internetking.us",5000,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Boot Factory 2K+","bfbbs.no-ip.com",8888,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Borderline BBS","borderlinebbs.dyndns.org",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Bottomless Abyss BBS","bbs.bottomlessabyss.net",2023,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Brain Storm BBS (SSH)","bsbbs@bsbbs.com.br",22,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("BrainToys BBS","braintoys.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Brazi.net","brazi.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Brett Bender BBS","207.90.251.241",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Brewery BBS","thebrewery.servebeer.com",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Brian's Blog TWGS","tw2002.briancmoses.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Brigandine","brigandine.org",9390,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Brokedown Palace BBS","palace.brokedownpalace.online",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Broken Bit Syndicate","www.brokenbit.us",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Broken Bubble","bbs.thebrokenbubble.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("BUEMA BBS","bbs.buema.ch",2300,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Bumgun Club BBS","bumgun.club",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Butterfly BBS","211.68.71.66",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Byte Me BBS","chat.hohimer.org",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("ByteBarn BBS","bbs.bytebarn.de",2300,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("C3BBS","c3bbs.retronetworking.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("C64 Pub","bbs.c64.pub",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Cabana Bar BBS","bbs.cabanabar.net",11123,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Cabin BBS, The","thecabinbbs.com",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Camelot BBS","camelotb.synchro.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Canerduh BBS","bbs.canerduh.com",23905,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Capital Station BBS","csbbs.dyndns.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Capitol City Online BBS","capitolcityonline.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Captain's Quarters BBS II","cqbbs.ddns.net",6800,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Castle BBS","47.46.52.130",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Castle Rock BBS","cedarvalleybbs.com",2424,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Catpit BBS","bbs.cis92.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Catsweat TWGS","24.88.72.99",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Cave BBS","cavebbs.homeip.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("CB2 Micro BBS","email.qrp.gr",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Cbaxyz TWGS","tdod.org",2002,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("CBBS/TN","cbbs.mitsaltair.com",8800,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("CCUW BBS","rtc.to",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("CCX BBS","bbs.ccxbbs.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("CedarValley BBS","cedarvalleybbs.com",2525,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("CedarValley BBS 2","cedarvalleybbs.com",2626,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Cement City","scenewall.bbs.io",4000,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Censorship BBS","blog.zenithrifle.cfd",8888,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Central Ontario Remote (Mystic)","centralontarioremote.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Central Ontario Remote (TWGS)","centralontarioremote.net",2002,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Centronian BBS","bbs.centronian.ca",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Centrum BBS","bbs.ninthchevron.com.au",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Cheez Daddy's House of Funk","atari8.us",10001,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Chimia BBS","chimia.se",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Choice Core BBS (1st)","1stchoicecore.co.nz",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Choice Core BBS (2nd)","2ndchoicecore.nz",1024,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Chookfest BBS","bbs.chookfest.net",6800,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Chris BBS","5.231.180.215",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Christian Fellowship","cfbbs.no-ip.com",26,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Chrome 30 BBS","3.136.234.155",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Chrysalis Online Services TBBS BBS","chrysalisbbs.org",8888,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("CIA Amiga BBS","ciaamiga.org",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("CIRCL's BBS","bbs.circl.lu",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Citadel 64 BBS","citadel64.thejlab.com",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Cittadella BBS","bbs.cittadellabbs.it",4001,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("City on the Edge of Forever","interzone.annexia.xyz",2002,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("CJ's Place","cjsplace.thruhere.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Clacker Works","cw.qc.to",9000,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Classic BBS","board.classicbbs.net",9339,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Classic Computing BBS","bbs.classiccomputing.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Classic Macs BBS","macos.retro-os.live",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Clover BBS","51.89.167.62",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Clover Love (Chinese)","segaa.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Clube da Insonia BBS","bbs.conf.eti.br",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Clutch","clutchbbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Coal Mine BBS","84.104.78.157",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("CodeRed BBS","coderedmud.servegame.com",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Cold Fusion BBS","cfbbs.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Cold Winter Knights","bbs.coldwinterknights.net",8888,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Colorado Springs Central Net TWGS","cscnet1.net",2002,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Colorado Springs Network","cscnet1.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Colossus BBS","bbs.qzwx.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Commander Central","45.10.160.94",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Commodore 4ever BBS","c4everbbs.ddnsgeek.com",20098,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Commodore Image","cib.dyndns.org",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Commodore Image II","cib.dyndns.org",6401,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Commodore Image III","cib.dyndns.org",6402,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Comms Nuts BBS","203.38.121.134",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Company Citadel BBS","www.companycitadel.us",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Computer Express","cebbs.costakis.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Computer God","cpugod.synchro.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Concrete Roots","concreteroots.servebbs.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Constructive Chaos BBS","conchaos.synchro.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Constructive Chaos TWGS","conchaos.synchro.net",2002,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Convolution","convolution.us",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Cool Blue TWGS","76.147.103.179",2002,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Cool David","bbs.cooldavid.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Cottonwood BBS","cottonwoodbbs.dyndns.org",6502,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Crack In Time BBS","crackintimebbs.ddns.net",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("CrappieCracker Online BBS","www.crappiecracker.com",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Crazy Eric's BBS","bbs.crazyerics.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Crazy Paradise","cpbbs.de",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Crusty Chicken TWGS","69.4.62.151",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Crypt BBS (2)","thecrypt.synchronetbbs.org",513,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Crystal Palace","cptalker.com",9900,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Crystal Set","zl4kj.nz",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Cyber Sword","bbs.excalibursheath.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("CyberDen BBS","167.172.127.245",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Cyberia BBS","sysgod.org",23000,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Cyberspace BBS (Synchronet)","cyberspacebbs.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Cyberspace BBS (Worldgroup)","cyberspacebbs.net",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Cyrellia BBS","bbs.cyrellia.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("D0P3 BBS","bbs.intersrv.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Danger Bay BBS","dangerbaybbs.dyndns.org",1337,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Dank Domain","play.ddgame.us",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Dark Endless","darkendlessbbs.hopto.org",6510,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Dark Game BBS","darkgame.buanzo.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Dark Realms","bbs.darkrealms.ca",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Dark Systems BBS","bbs.dsbbs.ca",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Dark Wastelands","darkwastelands.com",8888,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("DarkAges BBS","serverme.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("DarkForce! BBS, The","darkforce-bbs.dyndns.org",1040,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Darklevel","darklevel.hopto.org",64128,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("DarkMatter's TWGS","twgs.geekm0nkey.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Darkwood BBS","darkwood.ddns.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Datotal","datotal.net",35723,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Dave's BBS","143.223.235.160",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Dawn of Demise (MajorBBS)","tdod.org",3000,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Dawn of Demise (Synchronet)","tdod.org",5000,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Dawn of Demise (Worldgroup)","tdod.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Dead Carrier BBS","the-rotten-core.strangled.net",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Dead Internet Society","deadinternet.synchronetbbs.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Dead Zone BBS","dzbbs.hopto.org",64128,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Deadbeatz BBS","deadbeatz.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Death Row BBS","deathrow.servebbs.org",1001,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("DeepSkies BBS","bbs.deepskies.com",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Delta City BBS","deltacity.se",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Demigoth BBS","bbs.demigoth.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Demonsnet BBS","demonsnet.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Desert Rats Sanctuary BBS","bbs.kn6q.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Desert Rats Sanctuary TWGS","bbs.kn6q.org",2002,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("DHXY","dhxy.info",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Diamond Mine Online (Synchronet)","bbs.dmine.net",24,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Diamond Mine Online (WWIV)","bbs.dmine.net",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Digicom BBS","bbs.digicombbs.com",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Digital Asylum","digitalasylum.com.ar",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Digital Dial BBS","digitaldial.homeunix.com",2300,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Digital Distortion","bbs.digitaldistortionbbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Digital Dreams","ddreams.synchro.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Digital Lethargia BBS","www.diglet.ca",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Digital Post","thedigitalpost.freeddns.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Digital Rainbow","bbs.digitalrainbow.info",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Digital Warfare","bbs.digital-warfare.net",10281,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Digital Zone","5.150.245.20",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Dime BBS","alcoholidaybbs.com",94,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Disconnected by Peer BBS","bbs.disconnected-by-peer.at",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Diskbox ][","tag.diskbox2.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Distortion","d1st.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("DJ Dave BBS","djdave.uk",8088,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("DJ's Place","bbs.impakt.net",6502,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("DLWX BBS","107.175.69.10",60023,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("DniproWave BBS","bbs.net.ua",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Dock Sud","bbs.docksud.com.ar",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Dogtown BBS","bbs.kiwi.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Donghua Univ. Oriental Town","bbs.ndhu.edu.tw",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Door Games Unlimited","dgu.strangled.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Dove Only","casper.homeip.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("DownUnder BBS","202.90.240.159",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Drakefire BBS","bbs.drakefire.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Dream Garden","cd.csie.io",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Dream Land BBS","ccns.cc",3456,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Dreamland BBS","104.174.3.6",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Dreamline BBS","din.asciiattic.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("DUAO BBS","hermes.okyler.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Dundarach BBS","dundarach.tplinkdns.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Dungeon BBS","59.167.142.49",22,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Dura-Europos","dura-bbs.net",6359,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Dynamite BBS (1)","dynamite.bbsing.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Dynamite BBS (2)","dynamite.synchronetbbs.org",513,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Dyslexic Donkey","dydo.erb.pw",1337,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Eagle's Dare BBS","bbsdoors.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Eat My Shorts! BBS","ems-bbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Echo Base BBS","96.27.249.221",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Echo Chamber BBS","echochamber.zapto.org",3640,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Eclipse BBS","eclipsebbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Efectolinux","bbs.efectolinux.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Eldritch Clockwork","eldritchclockwork.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Electraphysics","142.11.212.221",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Electronic Chicken BBS","bbs.electronicchicken.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Elevator BBS","162.212.158.202",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Emerald Hill BBS","bbs.emeraldhill.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Emerald Valley","bbs.emeraldvalley.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Empire of the Dragon BBS","bbs.eotd.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("EMU486","bbs.emu486.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Enchanted BBS","47.38.20.227",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("End Of The Line BBS","endofthelinebbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("ENiAC 2.0 BBS","eniacv2.net",1337,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Enigma BBS","enigma-bbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Enigma Echo","79.253.89.153",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Enlight BBS","enlight.hopto.org",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Enterprise BBS","enterprisebbs.ddns.net",1701,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Entropy BBS","121.99.249.4",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("ERICADE Network","the.ericade.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Error 200 Tech BBS","bbs.error200.tech",1337,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Error 404 (TWGS)","error404bbs.ddns.net",24,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Error 404 BBS File Server","error404bbs.ddns.net",513,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Error 404 BBS Phone Book","error404bbs.ddns.net",419,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Escape To Other Worlds","etow.synchro.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Eternal Domain BBS","bbs.eternaldomain.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Ethernet Gateway","ethernetgateway.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Exoplanet","exoplanetbbs.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Extreme BBS","bayvillewireless.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Extricate BBS","bbs.extricate.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Eye of the Beholder","fido.beholderbbs.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Eye of the Storm","on.the.net.nz",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Fading Black","23.95.146.28",8282,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Faith Collapsing BBS","bbs.faithcollapsing.com",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Faker BBS","thafaker.crabdance.com",8088,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Family BBS","familybbs.ddns.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Fatcats BBS","fatcatsbbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("FDD1","fdd.one",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Fennec BBS","50.116.41.177",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Fercho BBS","ferchobbs.ddns.net",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("File Bank BBS","tfb-bbs.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Files 4 Fun BBS","bbs.f4fbbs.com",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Fireball Express (VADV)","vadv.fireballex.com",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Fireside BBS","firesidebbs.com",23231,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("First Division","158.174.185.101",1987,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("FlipperZero BBS","bbs.gglab.cloud",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("FlupH BBS","fluph.zapto.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Fluxpod Information Exchange","fix.no",24,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("FMRL","fmrl.throwbackbbs.com",2324,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Foenix Rising (1)","192.184.90.222",256,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Fool's Quarter BBS","fqbbs.synchro.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Forem XE BBS","foremxebbs.ddns.net",9999,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Forgotten Memories","dazexy.synology.me",52323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Forze BBS","bbs.opicron.eu",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Free Corner","bbs.debonne.eu",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Freeside BBS","freeside.bbs.io",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Freeway BBS","freeway.vkradio.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("French Connection","72.38.168.118",31023,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Fria Bad BBS","78.69.198.127",64128,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Frozen Floppy BBS","bbs.retrohack.se",64128,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Frugal Computing BBS","frugalbbs.com",513,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("fTelnet Demo Server","bbs.ftelnet.ca",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Fuji Summit","winnow.1q1.me",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Funtopia","funtopia.synchro.net",3023,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Furry Refuge","bbs.furryrefuge.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Future World II","fw2.cnetbbs.net",6800,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Futureland","futureland.today",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Galactic Explorers TWGS","galacticexplorers.servegame.com",22002,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Galaxy 74 BBS","galaxy74bbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Game Master","bbs.game-master.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Gamenet BBS Network","gamenet.synchronetbbs.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Gate BBS (Synchronet)","thegateb.synchro.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Gate BBS (WWIV)","thegateb.synchro.net",2424,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("GatorNet HQ BBS","gatornet.us",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("GCC-BBS","gcc-bbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("GDOS BBS","gdos.synchronetbbs.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("GeekCafe.XYZ","geekcafe.xyz",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Generation III Pot-D","geniv.dyndns.org",150,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Genetic-Point BBS","g-point.tunk.org",500,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Ghosts in the Machine","ghostmachine.ddns.net",1717,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("GigaBite BBS","bbs.gigabite.se",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("GlitchNet","50.115.170.113",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Global Chaos BBS","globalchaosbbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Global Village BBS","the.globalvillagebbs.net",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Goldmine Community Door Game Server","goldminedoors.com",2513,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Goof's Garage","goofsgarage.com",6464,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Goosenet BBS","bbs.g00r00.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Grapevine BBS","99.74.203.226",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Greenhead BBS","bbs.greenhead.ca",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Greywolf's Den","greywolf.synchro.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Gridlock BBS","gridlock.synchronetbbs.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Grimoire BBS","grimoirebbs.sytes.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Grinches Realm, The","tgr.freeddns.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Ground Control BBS","gcbbs.net",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Ground Zero BBS","71.239.223.149",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Guardian of Forever","guardian.synchro.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Guru BBS","bbs.bajer.cz",32,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Haciend El Bananas","haciend.com",8821,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Hackmeeting 0x1B BBS","95.217.16.88",8888,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Hagar's Helpline","hagars.org.uk",24,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Halcyon BBS","halcyonbbs.scisweb.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Halls of Valhalla BBS","hovalbbs.com",2333,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Happyland","citadel.dc540.org",23230,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Harbor BBS","96.30.192.92",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Hard Drive Cafe","hdcbbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Hated Reality","hatedreality.homeunix.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Hawaii BBS Atari 8 Bit","atari-bbs.zapto.org",8888,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Hax0r's Palace","telnet.unknownrealm.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Heatwave","heatwave.ddns.net",9640,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Heights BBS","heightsbbs.heightspc.net",6860,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Herbies BBS","herbies-bbs.ddns.net",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Herbies BBS II","herbies-bbs.ddns.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Herbies BBS III","herbies-bbs.ddns.net",2424,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("HeXed BBS","hexedbbs.com",23999,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Hidden BBS","the-hidden.hopto.org",64128,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Hidden Paradise","hpbbs.dyndns.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Hidden Paradise II","hpbbs.dyndns.org",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("High Desert BBS","highdesertbbs.ddns.net",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Highernest TWGS","199.244.48.171",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("HispaMSX BBS","bbs.hispamsx.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Hobbit Empire","bbs.hobbitempire.net",6501,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Hobbit Station BBS","wfido.ru",1234,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Hobby Line! BBS","hobbylinebbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Hohimer BBS","mail.hohimer.org",1336,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Hold Fast BBS","interzone.annexia.xyz",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Holodeck BBS","ufpgc.com",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Hologram Computing BBS","sbbs.hologramcomputing.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Honey-At-Home","31.133.0.38",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Horizon BBS","bbs.horizonbbs.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("House of Baud BBS","houseofbaud.com",8888,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Huanian Xiaoji","literature.twbbs.io",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("HyNET BBS","bbs.hyena.network",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Hysteria BBS","bbs.retrorewind.ca",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("IB-BBS","bbs.ibbs.be",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("ICARUS","44.31.91.213",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Ice Castle BBS","ice-castle-bbs.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Ilefinian Castle","bbs.elwynor.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Imzadi Box","box.imzadi.de",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Inconsistency BBS","66.228.57.87",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Infinite Dream BBS","aws1.fmerino.com.br",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Infonet BBS","bbs.rclabs.com.br",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Insane Asylum BBS","tiabbs.synchro.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Insomnia","insomnia.synchronetbbs.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("INTAA BBS","bbs.intaa.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Integrated Telecommunications Centre","itcbbs.ddns.net",23000,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Iowa Student Assc. BBS (ISCA)","bbs.iscabbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("IPTIA BBS (Synchronet)","bbs2.ipingthereforeiam.com",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("ISIS Unveiled","70.123.70.30",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("ITBnet BBS","bbs.itbnet.eu",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Itchy Butt BBS (Color 64)","itchybutt.org",6502,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Jacob's Hideout BBS","bbs.jacobcat.app",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Jamaica Joe's","bbs.jamaicajoes.net",8011,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("JawnCon0x1 BBS","157.245.141.84",8888,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Joe's Computer BBS","joesbbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Jolly Roger BBS, The","bbs.thejollyrogerbbs.com",8023,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("JumpStart BBS","www.exciter.ws",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Jungle BBS (1)","junglebbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Jungle BBS (2)","bbs.junglebbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Jupiter","jupiter.bbs.io",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Kats Alley","tka.8bitboyz.com",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Kaypro BBS","71.236.163.239",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("KCM BBS System","zahrl.ddns.net",2023,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("KD3net","bbs.kd3.us",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("KD8HFX","bbs.kd8hfx.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("KEEP BBS","thekeep.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Kernel Fortress","kernelfortress.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Killed In Action BBS","kia.zapto.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Kilobaud","bbs.kilobaud.xyz",8888,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Kilobyte","24.166.43.233",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Kingdom's End BBS (Mystic)","bbs.kingdomsendbbs.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Kingdom's End BBS (Synchronet)","sbbs.kingdomsendbbs.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Kirika BBS","andcycle.idv.tw",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("KiwiMates","96.231.233.47",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Korenblom","bbs.korenblom.nl",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Kraaby Gamer BBS","kraaby.synchro.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Kuehlbox","kuehlbox.wtf",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Lab BBS, The","bbs.dicksonlabs.net",2325,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Lake House BBS","lakehouse.lilpenguins.com",2333,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Land of Frogs and Contemplation","lofac.mintyfresh.love",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Land of the Lost","landofthelost.ca",2300,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Landover BBS","landover.synchronetbbs.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Last Rangers' BBS","lastrangers.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Leisure Time BBS","bbs.riddells.net",10023,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Level 29","bbs.fozztexx.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Lexicon BBS (Image BBS)","lexiconbbs.com",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Liane BBS","bbs.vslib.cz",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Lilac Community BBS","lilacbbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Liquid Digital","98.212.225.126",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Live Wire BBS","livewirebbs.com",1025,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Local Yocal BBS","localyocalbbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Lord Raptor's Domain","150.221.218.212",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Lord.stabs.org","lord.stabs.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Lost Cause Halfway House","lostcause.house",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Lost Caverns BBS","tlcbbs.dynu.net",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Lost Chord BBS (Commodore BBS)","tlcbbs.synchro.net",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Lost Chord BBS (Searchlight BBS)","tlcbbs.synchro.net",6023,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Lost Chord BBS (Synchronet BBS)","tlcbbs.synchro.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Lostways BBS","98.144.7.205",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("LowCrash DEV BBS","bbs.lowcrash.dev",8888,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("LSNET Archive","bbs.lsnet.dev",513,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Luggi BBS","83.218.168.105",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Lunar Mod","bbs.beanzilla.net",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Lunatics Unleashed BBS","lunaticsunleashed.ddns.net",2333,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Lytical HackFund BBS","134.209.40.1",31337,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("M. Station","mstation.servebbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Machdyne BBS","206.189.226.31",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Made To Raid","bbs.madetoraid.com",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Madman with a Blue Box","madmanbbs.ddns.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("MadWorld BBS","www.madworldbbs.com",52146,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Magic Systems","86.88.76.77",6323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Magnum BBS","magnumbbs.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Mahoney-Clan TWGS","209.126.4.147",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Maiden's Realm BBS","bbs.maidensrealm.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Maiks Place BBS","bbs.maik.ch",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Major Mudd","majormud.gotdns.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("MajorBBS Official Demo BBS","bbs.themajorbbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Maker BBS","73.11.3.16",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Malevolence","jf2.elderec.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Malte","bbs.swedishchef.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Maniac Zone","tmz.synchronetbbs.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Manic Modem BBS","telnet.manic-modem.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Mark Van Daele's TWGS","game.tw2002.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Master Boot Record","mbrserver.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("MasterCom","bbs.sunspothq.dyndns.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Mastodon","mastodon.uy",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("MaxBBS","maxbbs.ddns.net",24023,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Mbpeikert","mbpeikert.ddns.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("MBSE Professional Dev BBS","phoenix.bnbbbs.net",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Medusa BBS","medusagaming.ca",230,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Mega BBS Public BBS System","themegabbs.com",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Mel's Diner BBS","bbs.greenphosphor.ca",6623,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Memphis TW BBS","bbs.memphistw.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Memphis TW TWGS","bbs.memphistw.org",2002,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Metal Zone","tmzbbs01.synchro.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Metro Olografix","bbs.olografix.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("MicroBlaster TWGS","microblaster.net",2002,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Micropolis BBS","89.58.56.146",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Microtown BBS","microtownbbs.com",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Midnight Club","club.midnight-club.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Midnight Lounge","67.149.17.69",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Mimac Rebirth","mimac.bizzi.org",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Missing Links","mlinks.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Miya Net","miyanet.moe",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Mizuki Community (Newsmth BBS)","bbs.newsmth.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Modemo Tider","modematider.selstam.nu",50023,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Moe's Tavern","moetiki.ddns.net",27,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Mojo's World BBS","mojo.synchro.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Monochrome","mono.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Monterey BBS (Daydream)","137.184.84.9",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Monterey BBS (Mystic)","montereybbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Moon Base Alpha (TWGS)","mba.dnsalias.com",2002,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Moon Base Alpha (VADV)","mba.dnsalias.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Moratahack","moratahack.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("MorningSide Mortuary","mortuary.ddns.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Mousenet","bbs-mousenet.dynip.online",8889,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Mouth of Hell BBS","mouthofhell.duckdns.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Mozy's Swamp and Red Dwarf BBS","bbs.mozysswamp.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Mozy's Swamp and Red Dwarf TWGS","bbs.mozysswamp.org",24,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("MSmac BBS","msmacbbs.maletazul.pt",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("MtlGeek (Synchronet)","mtlgeek.synchro.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("MtlGeek (TWGS)","mtlgeek.synchro.net",2002,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Muinet","muinet.com",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("MULTINUBE-BBS","multinube.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Music Station","bbs.bsrealm.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Mutiny BBS (1)","mutinybbs.com",2332,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Mutiny BBS (2)","mutiny.cigdangle.com",65023,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Mutiny Brazil","51.222.231.228",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Mutiny Community","mutinybbs.com",2300,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("My Retro Computer","myretrocomp.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Mysmth BBS","bbs.mysmth.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Mysteria Majicka BBS","majicka.at2k.org",1955,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Mystic Garden","bbs.akitsune.dev",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Mystic Hobbies","mystic-hobbies.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Mystic Night BBS","69.244.173.57",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Mystic Realms","mysticrealms.ddns.net",11000,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Mystic Rhythms BBS","mystic.wwivbbs.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Mystical Realm BBS","mysticalrealmbbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Mythical Kingdom Tech BBS","ice.lilacway.com",3000,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Mythical Kingdom Tech SBBS","bbs.mythicalkingdom.com",5023,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Nanyang Inn","bbs.nykz.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("NE BBS","nebbs.servehttp.com",9223,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("NerdRage BBS","142.90.39.212",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Nervous Hospital","thenervoushospital.com",1996,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Netcrave Communications","bbs.netcrave.io",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Netpoint BBS","netpoint.webhop.me",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Netpoint TWGS","netpoint.webhop.me",2002,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Nettwerked BBS","nettwerked.synchronetbbs.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("NetVillage Sysop Community","96.231.233.50",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Never Never Land BBS","neverneverlandbbs.com",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("New World of the Internet","209.141.35.127",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Nexus BBS","nexus.aefinity.io",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Nick Gawronski's BBS","nick1.vs.mythic-beasts.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Nightbite BBS","nightbite.redirectme.net",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Nikom BBS","bbs.nikom.org",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Nine Worlds BBS","thenineworlds.dnshome.de",923,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Ninjalane Labs BBS","209.161.6.234",223,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Nite Eyes BBS","bbs.lizardmaster.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("NiteLite BBS","nitelite.ddns.net",9000,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Nitro Store","52.3.252.74",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("No Carrier BBS","bbs.wehack.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Non-Existant BBS","70.59.199.227",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Northern Palace","thenorthernpalace.com",2020,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("NostalMania","nostalmania.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Not Cows","45.63.69.192",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Nottingham BBS","nottinghambbs.com",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Noverdu","noverdu.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("NoWhere TWGS","joestavern.ddns.net",2002,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("NRG BBS Systems","nrgbbs.ddns.net",520,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Nuclear Club","nuke.club",513,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Nut Asylum (Mystic)","108.29.0.206",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Nut Asylum (Wildcat)","108.29.0.206",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Oasis BBS","oasisbbs.hopto.org",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Off The Wall","offthewall.dmxrob.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Oiran Alien Museum","libido.cx",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Old Highland Borg","ohb.synchronetbbs.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Old Net BBS","theoldnet.com",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Old School BBS","oldschool.synchronetbbs.org",513,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Old Time BBS (Mystic)","oldtimebbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Old Time BBS (Synchronet)","206.81.1.60",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Old Time's Sake BBS","otsbbs.ddns.net",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Oldest Future Object","ofo.tw",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Onix BBS","onixbbs.servebbs.com",2525,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Online BBS","online-bbs.selfhost.bz",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Onyx","185.139.32.178",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Operation Ivy BBS","opivy-bbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Optical Illusion BBS","optical.c64bbs.nu",64128,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("OPTO 22 BBS","bbs.opto22.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Orchestra BBS","sacrebase.mywire.org",486,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Oshaboy BBS","top-swadba.de",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Outer Limits, The","outerlimitsbbs.ddns.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Outpost 9 (BBS)","bbs.outpost9.co",2023,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Outpost 9 (TWGS)","tradewars.outpost9.com",2002,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Outpost BBS","bbs.outpostbbs.net",10323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Outwest BBS","outwest.synchro.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Owen2k6 Network BBS Service","owen2k6.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("P.U.L.S.E. BBS World HQ","pulsebbs.hopto.org",1984,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Paladium BBS","paladium.servebbs.com",20,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Palantir BBS","palantirbbs.ddns.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("PapiChulo's MajorBBS","75.31.92.35",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Paradox BBS (1)","paradoxbbs.synchronetbbs.org",513,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Paradox BBS (2)","18.222.210.54",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Paranoid BBS","88.80.185.171",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Part-Time BBS","ptbbs.ddns.net",8000,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Particles! BBS","particlesbbs.dyndns.org",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Party Bowl BBS","PartyBowlBBS.ddns.net",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Path Unknown BBS","pathunknown.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Pebkac.lol","pebkac.lol",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Penalty Box BBS","thepenaltybox.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Penny BBS","pennybbs.synchro.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Pepzi BBS","pepzi.eu",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Performance Leasing Systems","97.76.12.194",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Personal Home Cloud","75.26.216.248",24,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Pesto BBS","bbs.pewp.us",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Petit Caillou BBS","bbs.jayscafe.net",6402,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Phantasm","phantasm.bbs.io",4489,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Phantom BBS","bbs.phantombbs.info",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Pharcyde BBS","bbs.pharcyde.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Phaseshift","phased.port0.org",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Phatstar Teleporter","198.71.48.13",7777,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Phoenix BBS","phoenix.bnbbbs.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Phospher BBS","bbs.phospher.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("PhreakNet","bbs.phreaknet.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("PipeLine BBS","bbs.wantit.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Piranha BBS","blackflag.acid.org",27,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Pirate's Cove TWGS","38.188.130.43",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Pixelgrounds BBS (Enigma 1/2)","bbs.pixelgrounds.net",8888,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Pixelgrounds BBS (Worldgroup)","bbs.pixelgrounds.net",8887,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Planet Afr0","planetafr0.org",8888,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Plasma Sphere BBS","84.92.196.99",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Play LORD","playlord.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("PlayMajorMUD.com","playmajormud.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("PMF BBS","bbs.venerandi.it",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Poast BBS","bbs.poast.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Poignant Beacon (Pharos BBS)","bbs.pharos.rocks",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Port of Call BBS (Image)","pocbbs.duckdns.org",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Port of Call BBS (Renegade)","pocbbs.duckdns.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Port of Call BBS (Synchronet)","pocbbs.duckdns.org",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Pot O' Gold BBS","50.69.236.52",2513,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Pretzel Systems BBS","pretzels.onthewifi.com",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("PrimeNet","primenet.synchro.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Pro-Kegs","proline.ksherlock.com",6523,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Protoweb BBS","45.79.37.227",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Public Electronic Networked Information System penisys.online","6502",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Pweck's Retreat BBS","pwecksretreat.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("QL Dump","001english-eu.no-ip.biz",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Quantum Wormhole, The","bbs.erb.pw",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Quazar BBS Door Game Server","quazarbbs.dynu.net",2523,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Quest TWGS","thequesttwgs.game-host.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Quinn BBS","149.28.171.90",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Radio Freaks & Geeks","radiostream.amigaz.org",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Ragnarok's BBS","186.189.236.69",23021,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Raiders Inc. BBS","raidersbbs.zapto.org",1337,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Ralser Lab BBS","euklid.ddns.net",5745,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("RapidFire","rapidfire.hopto.org",64128,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Rats Den BBS","bbs.catracing.org",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Raven of the Storm","50.20.127.213",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Raveolution","raveolution.hopto.org",64128,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Rayzer's BBS","mail.hohimer.org",1336,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("RayzerNET BBS","connect.rayzer.net",2112,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Razz Pie BBS","razzpie.ddns.net",2300,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("RBB Systems Int'l","rbb.fidonet.fi",32,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("RC-BOX","rc2014.ddns.net",2014,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Realitycheck BBS","realitycheckbbs.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Realm BBS","therealm.synchro.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Realm of Darkness","bbs.trod.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Realm of Serion","connect.serionbbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Realm of the Wizard's Lair","bbs.b-wells.us",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Red Dragon BBS","108.52.154.224",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Red Star BBS","3.134.173.120",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Region 15 HQ","region15.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("ReichBBS","64.127.144.48",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Reign of Fire","call.rofbbs.com",6800,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Reign of Fire II","call.rofbbs.com",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Reign of Fire III","call.rofbbs.com",8502,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Reticulum Ace","bbs.acehoss.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Retro Archive","bbs.retroarchive.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Retro Running BBS","retrorunning.ddns.net",8880,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Retro Unboxers","flashbackbbs.sytes.net",6502,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Retro32 BBS","bbs.retro32.com",1337,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Retroaktiv BBS","retr0aktiv.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Retroconnect","retroconnect.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("RetroDigital BBS","rdnetbbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Retrogaming Activities","react-bbs.nikoh.it",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Retrograde BBS","rtg.dyndns.biz",6428,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Retrograde II BBS","cib.dyndns.org",6404,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("RetroLair BBS","retrolair.amigaretro.net",6800,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("RetroNet Neo","retronetneo.synchronetbbs.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("RetroSwim BBS","ezycom.retroswim.net",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Retroverse","bbs.retroverse.au",23023,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Reverse Polarity","revpol.lovelybits.org",1337,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Richard's Fun House","richardf.synchro.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Ricks BBS","ricksbbs.synchro.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Rise N' Shine BBS","rns.risenshinebbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("River Styx BBS","riverstyx.ddns.net",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("RMSBBS","rmsbbs.ddns.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Rock BBS III","therockbbs.net",10023,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Rockville Tavern","bbs.rockvilletavern.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Rogue Galaxy TWGS","tw.roguegalaxy.com",2002,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Roon's BBS","bbs.roonsbbs.hu",1212,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("RougeNet BBS","bbs.roguenet.work",8888,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Roughneck BBS","host.roughneckbbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Rougue BBS (Chinese)","35.201.128.35",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Rusty Mailbox","trmb.ca",2030,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Sanctuary BBS","sanctuary.zapto.org",1541,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Sanctum II BBS (Mystic)","sanctumbbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Sandnes BBS","stokmarknes.org",24,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Sands of Time","162.243.54.214",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Santronics R&D Beta Site","3.132.92.116",24,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Santronics Software","online.winserver.com",24,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Satellite4","satellite4.dynu.net",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("SBB Systems","bbs.sbbsystems.com",8888,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Scene List (1)","scenelist.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Scene List (2)","87.212.201.57",4000,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Scooby's Doo BBS","scoobysdoo.ddns.net",2023,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Scratched Reality","reality.throwbackbbs.com",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("SD2IEC Test BBS","cib.dyndns.org",6403,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("SDF-1 BBS","bbs.sdf1.net",5023,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Sea Breeze Gaming Network (Synchronet)","seabreeze.servegame.com",31,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Sea Breeze Gaming Network (TWGS)","seabreeze.servegame.com",2002,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Sea Breeze Gaming Network (Worldgroup #2) seabreeze.servegame.com","32",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Sea Breeze Gaming Network (Worldgroup)","seabreeze.servegame.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Sea of Fantasy","seaoffantasy.synchronetbbs.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Seattle BBS (Chinese)","seattle.tw",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Section 31 TWGS","sector31.lorfinglab.com",2002,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Septima Corporate BBS","3.72.83.34",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Shadow BBS","shadowbbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("ShadoWorks BBS","bbs.shadoworks.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Shadowscope","shadowscope.noip.us",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("ShadowThrone","109.247.190.78",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Shamrock BBS","104.246.170.121",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Shenk's Express","shenksxp.dyndns.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Shipwrecks & Shibboleths","shibboleths.org",800,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Shodan's Core","shodanscore.com",8086,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Shurato's Heavenly Sphere","shsbbs.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Silent Node BBS","silentnode.ddns.net",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("SiliconGraphics BBS","bbs.flexion.io",7777,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("SiliconUnderground","siliconu.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Silvermere","silvermerebbs.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Sinclair Retro BBS","retrobbs.sinclair.homepc.it",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Sinner's Heaven","207.246.74.70",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Skara Brea","80.7.90.17",31337,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Skynet BBS (1)","47.25.173.251",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Skynet BBS (2)","bbs.skynetbbs.com",20023,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Slackers BBS","slackers.ovh",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Slime City BBS","bbs.retrohack.se",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Snobsoft BBS","snobsoft.de",6401,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Soft Solutions","bbs.softsolutions.net.br",2023,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Solarflow BBS","solarflow.dynu.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Solo BBS","bbs.solobsd.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Sotano MSX BBS","sotanomsxbbs.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Sounds of Silence BBS","sos-bbs.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("South Central","southcentral.se",1023,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("SouthEast Star","sestar.synchro.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Southern Amis","southernamis.ddns.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Southwest NJ Retro Computing BBS","73.160.157.123",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("SpaceSST BBS","gallaxial.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Spades BBS","spades.synchronetbbs.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Spark Beer BBS","bbs.spark.beer",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Sparx BBS","sparx.bbs.io",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Sprawl BBS","202.61.251.17",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Squared Circle BBS","45.79.93.198",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Star Collision BBS","scbbs.nsupdate.info",61023,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Star Fleet HQ","bbs.sfhqbbs.org",5983,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Star Flight BBS","stateoftheark.ca",1990,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Star Killer's TWGS","sk-twgs.com",2002,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Star Mansion Returns","66.23.221.29",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Starbase 11 BBS","bbs.starbase11.de",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Starbase 21","bbs.starbase21.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Starbase Discovery","sb-discovery.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("StarDoc 134","bbs.stardoc134.com",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Starship Junkyard","bbs.starshipjunkyard.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Steven's Hive BBS","stevensbbs.stevenshive.xyz",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Storm BBS","telnet.stormbbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Stormgate BBS","stormgate.synchronetbbs.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Strange Planet BBS","strangeplanet.org",6800,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Street Corner BBS","streetcorner.ddns.net",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Strip It To Ride","104.142.112.149",9000,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Subcarrier BBS","subcarrier.ignorelist.com",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Subhuman","subhuman.ddns.net",1338,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Sugar Test BBS","bbs.lizsugar.me",6000,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Sumxin BBS (Chinese)","39.105.182.131",6666,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Super Dimension Fortress (SDF-1)","sdf.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Support BBS","bbs.ddybing.no",1223,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Surf Shop BBS (1)","ssbbs.ddns.net",6510,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Surf Shop BBS (2)","ssbbs.ddns.net",6502,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Sursum Corda TWGS","sursum-corda.com",2002,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Sursum Corda! BBS","sursum-corda.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Swap BBS","dose.0wnz.at",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("SWATS BBS","swatsbbs.ddns.net",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Swedish User Group Of Amiga","suga.se",42512,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("SwissIRC BBS","bbs.swissirc.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Swords Of Chaos Forever BBS","bbs.soc4ever.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Synchronix","nix.synchro.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Sysop Solaris Dot Com (Menu)","sysopsolaris.ddns.net",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("System One BBS","cib.dyndns.org",6491,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("T0kerz Hut","t0kerZ.ddns.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Taco Pronto","tacopronto.bbs.io",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("TARDIS BBS (1)","bbs.cortex-media.info",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("TARDIS BBS (2)","rg1.retrogoldbbs.com",6411,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Tassie Bob BBS","bbs.tassiebob.com",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Technoanarchy","technoanarchy.synchronetbbs.org",513,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Techrono BBS","techrono.synchro.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Techware","bbs.techware2k.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("TelBox","telbox.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Telehack","telehack.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Tempest Fury BBS","tempestfury.d2g.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Terminal Obsession","terminal-obsession.hopto.org",1541,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Terra Brasilis","tbrasilis.ddns.net",23000,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Terran Empire","73.178.46.44",1017,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("TFSI BBS","bbs.tfsi.dev",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("The BBS","24.237.16.152",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Theo BBS","bbs.theoretically.net",60723,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("There Can Only Be One (TCOB1)","194.36.65.41",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("This Old Cabin (English)","bbs.thisoldcabin.net",6464,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("This Old Cabin (Swedish)","bbs.thisoldcabin.net",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Thrace BBS","bbs.tabakov.net",13023,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Three Blind Mice","threeblindmice.synchronetbbs.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Throwback BBS","bbs.throwbackbbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Thunder BBS","149.56.47.118",1023,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Thunder-Line BBS","thunder.synchro.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Thunderbolt BBS","wx4qzbbs.ddnsfree.com",49815,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Tigernet BBS","tigernet.dewindt.us",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Tilde BBS","tilde.sbs",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Time Warp BBS","twb.wrgnbr.com",6896,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Time Warp of Future","time.synchro.net",24,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Timelord BBS","teehill.adirondackpc.com",2020,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Titantic BBS Telnet, The","ttb.rgbbs.info",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Tomato Place","bbs.tomato.place",8888,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Tommy's Holiday Camp","vintage.thcbbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Too Lazy BBS","toolazy.synchro.net",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Tool Shed","toolshed.synchro.net",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Toxic Laboratory BBS","toxicbbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("TQPS","tqps.ddns.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Trade Wars Academy TWGS","tradewarsacademy.com",2002,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Trade Wars Club","ta97-portal.win",2002,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Trashcan BBS","bbs.thenet.gen.nz",2324,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Tsinghua Univ. (Fengqiao Stn.)","bbs.cs.nthu.edu.tw",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("TuxedoCat Lounge","bbs.tuxedocatbbs.com",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("TVRi BBS","fruity.turbit.eu",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("TW Lounge BBS","bbs.twlounge.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Twixed BBS","twixed.net",62323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Two Girl BBS","bbs.2girl.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Tycho Station","bbs.tychostation.it",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Uncensored!","uncensored.citadel.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Uncomfortable Business","bbs.uncomfortable.business",6423,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Undercurrents BBS","undercurrents.io",8088,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Underground BBS","www.theunderground.us",10023,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Undermine BBS","bbs.undermine.ca",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Undernet BBS","undernet.uy",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Unicyber BBS","84.70.148.185",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Unix-Bit BBS","x-bit.org",1336,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Unknown Realm (Mystic)","turealm.no-ip.org",3023,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Unknown Realm (PCBoard)","turealm.no-ip.org",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Unleashed BBS","www.unleashedinet.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("UORealms BBS","bbs.uorealms.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("US 99 BBS","bbs.quinnnet.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("UserClub BBS","userclub-bbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("USS Excelsior BBS","excelsiorbbs.ddns.net",2000,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Util's Retro BBS","retro.setsuid.net",8221,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Uzi Suicide","uzisuicide.servebbs.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("V01d C1ph3r","bbs.canerduh.com",23056,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Vague BBS","vague.ddns.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Valley BBS (1)","valleybbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Valley BBS (2)","valley64.com",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Vault BBS","thevaultbbs.ddns.net",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Veleno BBS","velenobbs.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Verify-Nebula","verify-nebula.kicks-ass.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Vern BBS","vern.cc",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Vertrauen","vert.synchro.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Vienna Matrix","176.66.246.98",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Violeti BBS","violetyggdrasil.live",1144,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Viper BBS, The","theviperbbs.ddnsfree.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Viper's Pit TWGS","sk-twgs.com",2002,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("VK7HDM's BBS","workstation.ddmcomputers.com.au",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("VOID BBS","voidbbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Vortex BBS (1)","vortexbbs.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Vortex BBS (2)","vortex.redirectme.net",3777,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("W4BFB","packet.w4bfb.org",2333,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("WABAC Machine BBS","wabac.ccsnet.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Wall BBS","99.53.196.18",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("War Ensemble BBS","warensemble.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Wastelands BBS","wastelands-bbs.net",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Wastelands BBS II","wastelands-bbs.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Weather Station BBS","bbs.weather-station.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Weed Net","weednet.synchronetbbs.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Westland BBS","bbs.korenblom.nl",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Westwood BBS","westwoodbbs.net",64738,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Whisky Lover's Amateur Radio BBS","wd1cks.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("WhiXard BBS","bruschetta.cc",1337,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Who Dares Wins Amiga BBS","whodareswinsbbs.uk",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Wildcat's Castle BBS","bbs.wccastle.net",2424,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Willamette Apple Connection (WAC) BBS","wacbbs.ddns.net",6502,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Willow Creek BBS","willowcreekbbs.dynu.net",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Windows 10 City","win10.retro-os.live",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Windy City Study House","bbs.windcity.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Wintermute BBS","wintermutebbs.ddns.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Wizard's Castle","wccastle.synchro.net",24,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Wizard's Rainbow","wizardsrainbow.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Wizzy BBS","wizzybbs.win",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("WORD BBS","wordbbs.hopto.org",64128,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Worlds Apart (TWGS)","tw.worldsapart.net",2002,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Wormhole II BBS","wh2bbs.us",2321,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Wreck Hall","bbs.wreckhall.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Wretched Beagle BBS","bbs.wretchedbeagle.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Wrong Number ][ BBS","wn2.wrgnbr.com",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Wrong Number ][ BBS Retro 1993!!","wn6.wrgnbr.com",6411,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Wrong Number ][ V2.0","cib.dyndns.org",6405,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Wrong Number ]I[ BBS","wn3.wrgnbr.com",6400,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Wrong Number IV BBS","wn4.wrgnbr.com",3000,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("X-Bit BBS","x-bit.org",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("X65.zone BBS (1)","bbs.x65.zone",8888,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Xibalba","xibalba.l33t.codes",44510,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Yard BBS","unknown.identi.ty.cg",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Zelch BBS","coffeemud.net",6502,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("ZenBBS","zen.kawasu.wtf",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Zenolab","zenolab.synchro.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("ZeroTwo's BBS","bbs.zerotwo.tech",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Zhupan BBS","213.142.147.47",8023,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Zone BBS","zonebbs.net",23,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Zooropa BBS","52.4.41.44",2323,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Zot TWGS","tw2002.zot.org",2002,1);
INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ("Zruspa's BBS","bbs.zruspas.org",23,1);

INSERT INTO config (config_name, config_value) VALUES ('HOST','0.0.0.0');
INSERT INTO config (config_name, config_value) VALUES ('BBS NAME','BBS Universal');
INSERT INTO config (config_name, config_value) VALUES ('PORT','9999');
INSERT INTO config (config_name, config_value) VALUES ('BBS ROOT','.');
INSERT INTO config (config_name, config_value) VALUES ('DEFAULT BAUD RATE','2400');
INSERT INTO config (config_name, config_value) VALUES ('DEFAULT TEXT MODE','ASCII');
INSERT INTO config (config_name, config_value) VALUES ('THREAD MULTIPLIER','4');
INSERT INTO config (config_name, config_value) VALUES ('DATE FORMAT','YEAR/MONTH/DAY');
INSERT INTO config (config_name, config_value) VALUES ('DEFAULT TIMEOUT','10');
INSERT INTO config (config_name, config_value) VALUES ('FILES PATH','files/files/');
INSERT INTO config (config_name, config_value) VALUES ('LOGIN TRIES','3');
INSERT INTO config (config_name, config_value) VALUES ('MEMCACHED HOST','localhost');
INSERT INTO config (config_name, config_value) VALUES ('MEMCACHED PORT','11211');
INSERT INTO config (config_name, config_value) VALUES ('MEMCACHED NAMESPACE','BBSUniversal::');
INSERT INTO config (config_name, config_value) VALUES ('PLAY SYSOP SOUNDS','TRUE');
INSERT INTO config (config_name, config_value) VALUES ('USE DUF','FALSE'); -- Use "duf" or instead "df"?

INSERT INTO text_modes (text_mode) VALUES ('ASCII');
INSERT INTO text_modes (text_mode) VALUES ('ATASCII');
INSERT INTO text_modes (text_mode) VALUES ('PETSCII');
INSERT INTO text_modes (text_mode) VALUES ('ANSI');

INSERT INTO users (username,nickname,password,given,family,text_mode,baud_rate,accomplishments,retro_systems,birthday,access_level,max_columns,max_rows)
    VALUES (
        'sysop',
        'SysOp',
        SHA2('BBS::Universal',512),
        'System','Operator',
        (SELECT text_modes.id FROM text_modes WHERE text_modes.text_mode='ANSI'),
        'FULL',
        'I manage and maintain this system',
        'Stuff',
        now(),
        'SYSOP',
        264,
        50
    );
INSERT INTO permissions (id,view_files,show_email,upload_files,download_files,remove_files,read_message,post_message,remove_message,sysop,timeout)
    VALUES (
        LAST_INSERT_ID(),
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        65535
    );
INSERT INTO users (username,nickname,password,given,family,text_mode,accomplishments,birthday)
    VALUES (
        'testuser',
        'Testmeister',
        SHA2('test',512),
        'Test','User',
        (SELECT text_modes.id FROM text_modes WHERE text_modes.text_mode='ANSI'),
        'My existence is destined to end soon',
        now()
    );
INSERT INTO permissions (
    id
  )
  VALUES (
      LAST_INSERT_ID()
  );

INSERT INTO message_categories (name,description) VALUES ('General','General Discussion');
INSERT INTO message_categories (name,description) VALUES ('Atari 400/800/XL/XE','Atari 8 Bit Computers');
INSERT INTO message_categories (name,description) VALUES ('Atari ST/STE/TT/Falcon030','Atari 16/32 Bit Computers');
INSERT INTO message_categories (name,description) VALUES ('Commodore 8 Bit','Commodore 8 Bit Computers');
INSERT INTO message_categories (name,description) VALUES ('Commodore Amiga','Commodore Amiga Computers');
INSERT INTO message_categories (name,description) VALUES ('Timex/Sinclair','Timex/Sinclair Computers');
INSERT INTO message_categories (name,description) VALUES ('Sinclair','Sinclair Computers');
INSERT INTO message_categories (name,description) VALUES ('Heathkit','Heathkit Computers');
INSERT INTO message_categories (name,description) VALUES ('CP/M','CP/M Computers');
INSERT INTO message_categories (name,description) VALUES ('TRS-80','TRS-80 Discussion');
INSERT INTO message_categories (name,description) VALUES ('Apple II','Apple 8 Bit Computers');
INSERT INTO message_categories (name,description) VALUES ('Apple Macintosh','Apple Macintosh Discussion');
INSERT INTO message_categories (name,description) VALUES ('MS-DOS','MS-DOS Discussion');
INSERT INTO message_categories (name,description) VALUES ('Windows','Windows Discussion');
INSERT INTO message_categories (name,description) VALUES ('Linux','Linux Discussion');
INSERT INTO message_categories (name,description) VALUES ('FreeBSD','FreeBSD Discussion');
INSERT INTO message_categories (name,description) VALUES ('Homebrew','Homebrew Computers');

INSERT INTO messages (category,from_id,title,message) VALUES (1,1,'First (test) Message','This is a test');
INSERT INTO messages (category,from_id,title,message) VALUES (1,1,'First (test) Message 2','This is a test too');
INSERT INTO messages (category,from_id,title,message) VALUES (2,1,'First (test) Message','This is a test');
INSERT INTO messages (category,from_id,title,message) VALUES (3,1,'First (test) Message','This is a test');
INSERT INTO messages (category,from_id,title,message) VALUES (4,1,'First (test) Message','This is a test');
INSERT INTO messages (category,from_id,title,message) VALUES (5,1,'First (test) Message','This is a test');
INSERT INTO messages (category,from_id,title,message) VALUES (6,1,'First (test) Message','This is a test');
INSERT INTO messages (category,from_id,title,message) VALUES (7,1,'First (test) Message','This is a test');
INSERT INTO messages (category,from_id,title,message) VALUES (8,1,'First (test) Message','This is a test');
INSERT INTO messages (category,from_id,title,message) VALUES (9,1,'First (test) Message','This is a test');
INSERT INTO messages (category,from_id,title,message) VALUES (10,1,'First (test) Message','This is a test');
INSERT INTO messages (category,from_id,title,message) VALUES (11,1,'First (test) Message','This is a test');
INSERT INTO messages (category,from_id,title,message) VALUES (12,1,'First (test) Message','This is a test');
INSERT INTO messages (category,from_id,title,message) VALUES (13,1,'First (test) Message','This is a test');
INSERT INTO messages (category,from_id,title,message) VALUES (14,1,'First (test) Message','This is a test');
INSERT INTO messages (category,from_id,title,message) VALUES (15,1,'First (test) Message','This is a test');
INSERT INTO messages (category,from_id,title,message) VALUES (16,1,'First (test) Message','This is a test');
INSERT INTO messages (category,from_id,title,message) VALUES (17,1,'First (test) Message','This is a test');

INSERT INTO file_types (type, extension) VALUES ('Plain Text','TXT');
INSERT INTO file_types (type, extension) VALUES ('ASCII Text','ASC');
INSERT INTO file_types (type, extension) VALUES ('Atari ATASCII Text','ATA');
INSERT INTO file_types (type, extension) VALUES ('Commodore PETSCII Text','PET');
INSERT INTO file_types (type, extension) VALUES ('DEC VT-102 Text','VT');
INSERT INTO file_types (type, extension) VALUES ('ANSI Text','ANS');
INSERT INTO file_types (type, extension) VALUES ('GitHub Markdown Text','MD');
INSERT INTO file_types (type, extension) VALUES ('Rich Text File','RTF');
INSERT INTO file_types (type, extension) VALUES ('Information File','INF');
INSERT INTO file_types (type, extension) VALUES ('Configuration File','CFG');
INSERT INTO file_types (type, extension) VALUES ('Microsoft Word Document','DOC');
INSERT INTO file_types (type, extension) VALUES ('Microsoft Word Document','DOCX');
INSERT INTO file_types (type, extension) VALUES ('Perl Script','PL');
INSERT INTO file_types (type, extension) VALUES ('Perl Module','PM');
INSERT INTO file_types (type, extension) VALUES ('Python Script','PY');
INSERT INTO file_types (type, extension) VALUES ('C Source','C');
INSERT INTO file_types (type, extension) VALUES ('C++ Source','CPP');
INSERT INTO file_types (type, extension) VALUES ('C Include','H');
INSERT INTO file_types (type, extension) VALUES ('C-Shell Script','SH');
INSERT INTO file_types (type, extension) VALUES ('Cascading Style Sheet','CSS');
INSERT INTO file_types (type, extension) VALUES ('Hypter-Text Markup Language','HTM');
INSERT INTO file_types (type, extension) VALUES ('Hypter-Text Markup Language','HTML');
INSERT INTO file_types (type, extension) VALUES ('Special Hypter-Text Markup Language','SHTML');
INSERT INTO file_types (type, extension) VALUES ('Javascript','JS');
INSERT INTO file_types (type, extension) VALUES ('Java Source','JAVA');
INSERT INTO file_types (type, extension) VALUES ('Information File','INF');
INSERT INTO file_types (type, extension) VALUES ('Macintosh File Descriptor','DS');

INSERT INTO file_types (type, extension) VALUES ('Portable Network Graphics Image','PNG');
INSERT INTO file_types (type, extension) VALUES ('JPEG Image','JPG');
INSERT INTO file_types (type, extension) VALUES ('CompuServe Graphics Interchange Format Image','GIF');
INSERT INTO file_types (type, extension) VALUES ('JPEG Image','JPEG');
INSERT INTO file_types (type, extension) VALUES ('Tagged Image File Format Image','TIFF');
INSERT INTO file_types (type, extension) VALUES ('Targa Image','TGA');
INSERT INTO file_types (type, extension) VALUES ('Web Image','WEBP');
INSERT INTO file_types (type, extension) VALUES ('Icon','ICO');

INSERT INTO file_types (type, extension) VALUES ('MPEG 4 Video','MP4');
INSERT INTO file_types (type, extension) VALUES ('Matroska Packaged Video','MKV');
INSERT INTO file_types (type, extension) VALUES ('Audio Video Interchange Video','AVI');
INSERT INTO file_types (type, extension) VALUES ('MPEG 4 Video','MPV');
INSERT INTO file_types (type, extension) VALUES ('MPEG 2 Video','MPG');
INSERT INTO file_types (type, extension) VALUES ('Motion JPEG Video','MJPG');

INSERT INTO file_types (type, extension) VALUES ('MPEG 2 Layer 3 Audio','MP3');
INSERT INTO file_types (type, extension) VALUES ('Advanced Audio Coding Audio','AAC');
INSERT INTO file_types (type, extension) VALUES ('Windows Audio','WAV');
INSERT INTO file_types (type, extension) VALUES ('Windows Media Audio','WMA');
INSERT INTO file_types (type, extension) VALUES ('Free Lossless Audio Compression Audio','FLAC');
INSERT INTO file_types (type, extension) VALUES ('Musical Instrument Digital Interface Audio','MID');
INSERT INTO file_types (type, extension) VALUES ('Tracker Audio','TRK');
INSERT INTO file_types (type, extension) VALUES ('Tracker Audio','MOD');

INSERT INTO file_types (type, extension) VALUES ('Atari 400/800/XL/XE Disk Image','ATR');
INSERT INTO file_types (type, extension) VALUES ('Atari 400/800/XL/XE Binary Executable','XEX');
INSERT INTO file_types (type, extension) VALUES ('Atari ST/STE/TT/Falcon GEM Program','PRG');
INSERT INTO file_types (type, extension) VALUES ('Atari ST/STE/TT/Falcon TOS Program','TOS');
INSERT INTO file_types (type, extension) VALUES ('Atari ST/STE/TT/Falcon TOS Takes Parameters Program','TTP');
INSERT INTO file_types (type, extension) VALUES ('Atari ST/STE/TT/Falcon Desk Accessory','ACC');
INSERT INTO file_types (type, extension) VALUES ('Atari ST/STE/TT/Falcon Extendable Desk Accessory','CPX');
INSERT INTO file_types (type, extension) VALUES ('Atari ST/STE/TT/Falcon Menu Resource','RSC');

INSERT INTO file_types (type, extension) VALUES ('7-Zip Compressed','7Z');
INSERT INTO file_types (type, extension) VALUES ('Zip Compressed','ZIP');
INSERT INTO file_types (type, extension) VALUES ('RAR Compressed','RAR');
INSERT INTO file_types (type, extension) VALUES ('Compressed Archive','ARC');
INSERT INTO file_types (type, extension) VALUES ('TAR Archive Compressed','TGZ');
INSERT INTO file_types (type, extension) VALUES ('TAR Archive','TAR');
INSERT INTO file_types (type, extension) VALUES ('GZip Compressed','GZ');

INSERT INTO file_types (type, extension) VALUES ('Excel','XLS');
INSERT INTO file_types (type, extension) VALUES ('eXtensibe Markup Language','XML');

INSERT INTO file_types (type, extension) VALUES ('MS-DOS Command Executable','COM');
INSERT INTO file_types (type, extension) VALUES ('MS-DOS Batch','BAT');
INSERT INTO file_types (type, extension) VALUES ('MS-DOS/Windows Executable','EXE');

INSERT INTO file_categories (title,description) VALUES ('BBS::Universal Specific','All Files Relating to BBS Universal');
INSERT INTO file_categories (title,description) VALUES ('General','General Files');
INSERT INTO file_categories (title,description) VALUES ('Atari 400/800/XL/XE','Atari 8 Bit Files');
INSERT INTO file_categories (title,description) VALUES ('Atari ST/STE/TT/Falcon030','Atari 16/32 Bit Files');
INSERT INTO file_categories (title,description) VALUES ('Commodore 8 Bit','Commodore 8 Bit Files');
INSERT INTO file_categories (title,description) VALUES ('Commodore Amiga','Commodore Amiga Files');
INSERT INTO file_categories (title,description) VALUES ('Timex/Sinclair','Timex/Sinclair Files');
INSERT INTO file_categories (title,description) VALUES ('Sinclair','Sinclair Files');
INSERT INTO file_categories (title,description) VALUES ('Heathkit','Heathkit Files');
INSERT INTO file_categories (title,description) VALUES ('CP/M','CP/M Files');
INSERT INTO file_categories (title,description) VALUES ('TRS-80','TRS-80 Files');
INSERT INTO file_categories (title,description) VALUES ('Apple II','Apple 8 Bit Files');
INSERT INTO file_categories (title,description) VALUES ('Apple Macintosh','Macintosh Files');
INSERT INTO file_categories (title,description) VALUES ('MS-DOS','MS-DOS Files');
INSERT INTO file_categories (title,description) VALUES ('Windows','Windows Files');
INSERT INTO file_categories (title,description) VALUES ('Linux','Linux Files');
INSERT INTO file_categories (title,description) VALUES ('FreeBSD','FreeBSD Files');
INSERT INTO file_categories (title,description) VALUES ('Homebrew','Homebrew Files');

INSERT INTO files (filename,title,file_type,description,file_size) VALUES ('BBS_Universal.png','BBS::Universal Logo',(SELECT id FROM file_types WHERE extension='PNG'),'The BBS::Universal Logo in PNG format',148513);
INSERT INTO files (filename,title,file_type,description,file_size) VALUES ('BBS_Universal_banner.vt','ANSI BBS::Universal Logo',(SELECT id FROM file_types WHERE extension='VT'),'The BBS::Universal Logo in ANSI format',533);

INSERT INTO news (
    news_title,
    news_content
  ) VALUES (
    'BBS Universal Installation',
    'BBS::Universal, written by Richard Kelsch, a Perl based BBS server designed for retro and modern computers has been installed on this server.'
);

-- Views

CREATE VIEW users_view
 AS
 SELECT
    users.id                             AS id,
    users.username                       AS username,
    CONCAT(users.given,' ',users.family) AS fullname,
    users.password                       AS password,
    users.given                          AS given,
    users.family                         AS family,
    users.nickname                       AS nickname,
    users.max_columns                    AS max_columns,
    users.max_rows                       AS max_rows,
    users.birthday                       AS birthday,
    users.location                       AS location,
    users.date_format                    AS date_format,
    users.baud_rate                      AS baud_rate,
    users.login_time                     AS login_time,
    users.logout_time                    AS logout_time,
    users.file_category                  AS file_category,
    users.forum_category                 AS forum_category,
    users.email                          AS email,
    users.access_level                   AS access_level,
    text_modes.text_mode                 AS text_mode,
    permissions.timeout                  AS timeout,
    users.retro_systems                  AS retro_systems,
    users.accomplishments                AS accomplishments,
    permissions.show_email               AS show_email,
    permissions.prefer_nickname          AS prefer_nickname,
    permissions.view_files               AS view_files,
    permissions.upload_files             AS upload_files,
    permissions.download_files           AS download_files,
    permissions.remove_files             AS remove_files,
    permissions.read_message             AS read_message,
    permissions.post_message             AS post_message,
    permissions.remove_message           AS remove_message,
    permissions.sysop                    AS sysop,
    permissions.page_sysop               AS page_sysop,
    permissions.play_fortunes            AS play_fortunes,
	permissions.banned                   AS banned
 FROM
    users
 INNER JOIN
    permissions ON users.id=permissions.id
 INNER JOIN
    text_modes ON text_modes.id=users.text_mode;

CREATE VIEW messages_view
 AS
 SELECT
    messages.id                          AS id,
    messages.from_id                     AS from_id,
    messages.category                    AS category,
    CONCAT(users.given,' ',users.family) AS author_fullname,
    users.nickname                       AS author_nickname,
    users.username                       AS author_username,
    messages.title                       AS title,
    messages.message                     AS message,
    messages.created                     AS created
 FROM
    messages
 LEFT JOIN
    users ON messages.from_id=users.id
 WHERE messages.hidden=FALSE;

CREATE VIEW files_view
AS
SELECT
    files.id                             AS id,
    files.filename                       AS filename,
    files.title                          AS title,
    file_categories.title                AS category,
    file_categories.id                   AS category_id,
    file_types.type                      AS type,
    file_types.extension                 AS extension,
    files.description                    AS description,
    files.file_size                      AS file_size,
    files.uploaded                       AS uploaded,
    files.endorsements                   AS endorsements,
    users.username                       AS username,
	users.nickname                       AS nickname,
	permissions.prefer_nickname          AS prefer_nickname,
    CONCAT(users.given,' ',users.family) AS fullname

FROM
    files
INNER JOIN
    file_categories ON files.category=file_categories.id
INNER JOIN
    file_types ON files.file_type=file_types.id
INNER JOIN
    users ON files.user_id=users.id
INNER JOIN
    permissions ON users.id=permissions.id;

CREATE VIEW bbs_listing_view
  AS
  SELECT
    bbs_id         AS bbs_id,
    bbs_name       AS bbs_name,
    bbs_hostname   AS bbs_hostname,
    bbs_port       AS bbs_port,
    users.username AS bbs_poster
  FROM
    bbs_listing
  INNER JOIN
    users ON users.id=bbs_listing.bbs_poster_id;

-- END
