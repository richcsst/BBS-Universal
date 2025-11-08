# BBS::Universal

![BBS::Universal Logo](files/files/BBS_Universal.png?raw=true "BBS::Universal")

A Perl based TCP-IP BBS catering to retro computers and that modem experience.

## CODE NOT EVEN CLOSE TO STABLE YET

Installing is at your own risk and likely will not be very useful to you at the moment, but if you want to track progress, then go ahead.

## INSTALLING

```bash
        perl Makefile.PL
        make
        make test
 [sudo] make install
        make veryclean
```

You will need a properly configured MySQL server.  You also need to modify the "conf/bbs.rc" to reflect your MySQL installation (including account) and make sure the file is not world readable.  You also need to run the "sql/database_setup.sql" file in mysql:

```bash
        sudo mysql -u root --skip-password < sql/database_setup.sql
```

You can use the default menu files or change them to your own taste.  See the manual for details.

## DESCRIPTION

A 100% Perl BBS server.  It supports ASCII, ANDI, ATASCII and PETSCII text formats.

## CONFIGURATION

The system requires a very minimal static configuration file to give access to the database.  The rest of the configuration is stored in the database.

The file **conf/bbs.rc** :

```
# Minimum Configuration for BBS Universal.  Only Database info goes here.
# The rest resides in the Database.  Comments and empty lines are ignored
# Make this file belong only to you via "chmod 600".

# Change the username and password to whatever you set your account to.

DATABASE NAME     = BBSUniversal
DATABASE TYPE     = mysql
DATABASE USERNAME = bbssystem
DATABASE PASSWORD = bbspass
DATABASE HOSTNAME = localhost
DATABASE PORT     = 3306
```

## SYSOP MENU FILE FORMAT

Note:  Add needed files are included in the distribution.  All you need to do is customize them for your BBS
```
# Key | Command | Color | Description
1|SYSOP LOGIN SYSOP|WHITE|Connect as user SysOp
2|SYSOP LOGIN USER|WHITE|Connect as another user
B|SYSOP BBS LISTINGS MANAGER|BRIGHT BLUE|BBS Listings Manager
D|SYSOP STATISTICS|MAGENTA|Display Statistics
E|SYSOP SHOW ENVIRONMENT|GREEN|Show Environmental Variables
F|SYSOP FILE MANAGER|YELLOW|File Manager
L|SYSOP LIST COMMANDS|COLOR 202|Commands & Tokens Reference
R|SYSOP RESTART|WHITE|Restart BBS
S|SYSOP SETTINGS|COLOR 125|Change System Settings
U|SYSOP USER MANAGER|CYAN|User Manager
X|SYSOP SHUTDOWN|WHITE|Shutdown BBS
---
[% BRIGHT RED     %]     [% BLACK LOWER RIGHT TRIANGLE %][% RESET                       %]  ____            _                   __  __
[% BRIGHT YELLOW  %]    [% BLACK LOWER RIGHT TRIANGLE %][% B_BRIGHT YELLOW  %] [% RESET %] / ___| _   _ ___| |_ ___ _ __ ___   |  \/  | ___ _ __  _   _
[% BRIGHT GREEN   %]   [% BLACK LOWER RIGHT TRIANGLE %][% B_BRIGHT GREEN   %]  [% RESET %] \___ \| | | / __| __/ _ \ '_ ` _ \  | |\/| |/ _ \ '_ \| | | |
[% BRIGHT MAGENTA %]  [% BLACK LOWER RIGHT TRIANGLE %][% B_BRIGHT MAGENTA %]   [% RESET %]  ___) | |_| \__ \ ||  __/ | | | | | | |  | |  __/ | | | |_| |
[% BRIGHT BLUE    %] [% BLACK LOWER RIGHT TRIANGLE %][% B_BRIGHT BLUE    %]    [% RESET %] |____/ \__, |___/\__\___|_| |_| |_| |_|  |_|\___|_| |_|\__,_|
[% BRIGHT CYAN    %][% BLACK LOWER RIGHT TRIANGLE %][% B_BRIGHT CYAN    %]     [% RESET %]        |___/
```

## MAIN MENU FILE FORMAT

Note:  Add needed files are included in the distribution.  All you need to do is customize them for your BBS
```
# KEY|COMMAND|COLOR|ACCESS LEVEL|DESCRIPTION
B|BBS LISTING|BLUE|USER|Show BBS List
O|FORUMS|WHITE|USER|Go To Forums
M|ACCOUNT MANAGER|WHITE|USER|Manage Your Account
F|FILES|WHITE|USER|Go To Files
N|NEWS|WHITE|USER|System News
A|ABOUT|WHITE|USER|About This BBS
U|LIST USERS|BRIGHT WHITE|USER|List Users
R|RSS FEEDS|RED|USER|Read External News Feeds
X|DISCONNECT|WHITE|USER|Disconnect
---
 __  __
|  \/  |___ _ _ _  _
| |\/| / -_) ' \ || |
|_|  |_\___|_||_\_,_|
[% FORTUNE %]
```

## LICENSE AND COPYRIGHT

Copyright © 2023-2025 Richard Kelsch

This program is free software; you can redistribute it and/or modify it under the terms of the Perl Artistic License.

