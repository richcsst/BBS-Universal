-- Create a fresh and new database

DROP DATABASE IF EXISTS BBSUniversal;
CREATE DATABASE BBSUniversal CHARACTER SET utf8;
USE BBSUniversal;

-- Tables

CREATE TABLE config (
	id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	config_name  VARCHAR(255),
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
    max_columns     SMALLINT UNSIGNED DEFAULT 132,
	max_rows        SMALLINT UNSIGNED DEFAULT 50,
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
	timeout         SMALLINT UNSIGNED DEFAULT 10
);

CREATE TABLE message_categories (
	id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	name        VARCHAR(255) NOT NULL,
	description MEDIUMTEXT NOT NULL
);

CREATE TABLE messages (
	id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	category INT UNSIGNED NOT NULL,
	from_id  INT UNSIGNED NOT NULL,
	title    VARCHAR(255) NOT NULL,
	message  MEDIUMTEXT NOT NULL,
	hidden   BOOLEAN DEFAULT FALSE,
	created  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE file_categories (
	id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	title       VARCHAR(255) NOT NULL,
	description MEDIUMTEXT
);

CREATE TABLE files (
	id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	filename     VARCHAR(255) NOT NULL,
	title        VARCHAR(255) NOT NULL,
	user_id      INT UNSIGNED NOT NULL DEFAULT 1,
	category     INT UNSIGNED NOT NULL DEFAULT 1,
	file_type    SMALLINT NOT NULL,
	description  MEDIUMTEXT NOT NULL,
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

INSERT INTO text_modes (text_mode) VALUES ('ASCII');
INSERT INTO text_modes (text_mode) VALUES ('ATASCII');
INSERT INTO text_modes (text_mode) VALUES ('PETSCII');
INSERT INTO text_modes (text_mode) VALUES ('ANSI');

INSERT INTO users (username,nickname,password,given,family,text_mode,baud_rate,accomplishments,retro_systems,birthday,access_level)
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
		'SYSOP'
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
INSERT INTO message_categories (name,description) VALUES ('Apple Macintosh','Macintosh Discussion');
INSERT INTO message_categories (name,description) VALUES ('MS-DOS','MS-DOS Discussion');
INSERT INTO message_categories (name,description) VALUES ('Windows','Windows Discussion');
INSERT INTO message_categories (name,description) VALUES ('Linux','Linux Discussion');
INSERT INTO message_categories (name,description) VALUES ('FreeBSD','FreeBSD Discussion');
INSERT INTO message_categories (name,description) VALUES ('Homebrew','Homebrew Computers');


INSERT INTO messages (category,from_id,title,message) VALUES (1,1,'First (test) Message','This is a test');

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
	permissions.page_sysop               AS page_sysop
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
	 message_categories.name              AS category_name,
	 CONCAT(users.given,' ',users.family) AS Author,
	 messages.title                       AS title,
	 messages.message                     AS message,
	 messages.created                     AS created
 FROM
     messages
 INNER JOIN
     message_categories ON messages.id=message_categories.id
 INNER JOIN
     users ON messages.from_id=users.id;

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
    permissions.prefer_nickname          AS prefer_nickname,
	users.username                       AS username,
    users.nickname                       AS nickname,
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

-- End
